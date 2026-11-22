#!/usr/bin/env python3
"""Kubernetes-style declarative AgentSystem validation and status observer.

Evaluates `.agents/system.json` (desired state) against observed local, GitHub,
and GCS state, producing standard Kubernetes-style component rows, Conditions,
and owner/agent reconciliation actions without mutating anything.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

API_VERSION = "agents.foodsavr.dev/v1alpha1"
KIND = "AgentSystem"
VALID_NAMESPACES = ("control-plane", "ci-runners", "observability", "delivery")


def _non_empty_str(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _non_empty_str_list(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_non_empty_str(item) for item in value)


def validate_system_manifest(manifest: Any, source: Path | str) -> list[str]:
    """Validate `.agents/system.json` against the AgentSystem contract."""
    errors: list[str] = []
    if not isinstance(manifest, dict):
        return [f"{source}: manifest must be a JSON object"]
    allowed_top = {"apiVersion", "kind", "metadata", "spec"}
    errors.extend(f"{source}: unknown top-level field {field}" for field in manifest if field not in allowed_top)
    if manifest.get("apiVersion") != API_VERSION:
        errors.append(f"{source}: apiVersion must be {API_VERSION!r}")
    if manifest.get("kind") != KIND:
        errors.append(f"{source}: kind must be {KIND!r}")

    metadata = manifest.get("metadata")
    if not isinstance(metadata, dict):
        errors.append(f"{source}: metadata must be an object")
    else:
        for field in ("name", "defaultBranch"):
            if not _non_empty_str(metadata.get(field)):
                errors.append(f"{source}: metadata.{field} must be a non-empty string")
        errors.extend(f"{source}: unknown metadata field {field}" for field in metadata if field not in {"name", "defaultBranch"})

    spec = manifest.get("spec")
    if not isinstance(spec, dict):
        errors.append(f"{source}: spec must be an object")
        return errors
    required_sections = {"controlPlane", "ciRunners", "router", "governance", "observability", "delivery"}
    for section in sorted(required_sections):
        if not isinstance(spec.get(section), dict):
            errors.append(f"{source}: spec.{section} must be an object")
    errors.extend(f"{source}: unknown spec section {field}" for field in spec if field not in required_sections)

    cp = spec.get("controlPlane")
    if isinstance(cp, dict):
        min_safe = cp.get("minPolicySafeProviders")
        if not isinstance(min_safe, int) or isinstance(min_safe, bool) or min_safe < 1:
            errors.append(f"{source}: spec.controlPlane.minPolicySafeProviders must be an integer >= 1")
        if not _non_empty_str(cp.get("requiredHooksPath")):
            errors.append(f"{source}: spec.controlPlane.requiredHooksPath must be a non-empty string")
        if not isinstance(cp.get("skillsSync"), bool):
            errors.append(f"{source}: spec.controlPlane.skillsSync must be a boolean")
        if cp.get("logsFormat") != "jsonl":
            errors.append(f"{source}: spec.controlPlane.logsFormat must be 'jsonl'")

    ci = spec.get("ciRunners")
    if isinstance(ci, dict):
        for field in ("providerAuthSecretsAnyOf", "agentAppSecretsAllOf", "mergeGateSecretsAllOf"):
            if not _non_empty_str_list(ci.get(field)):
                errors.append(f"{source}: spec.ciRunners.{field} must be a non-empty array of strings")
        if "mergeGateWorkflow" in ci and not _non_empty_str(ci.get("mergeGateWorkflow")):
            errors.append(f"{source}: spec.ciRunners.mergeGateWorkflow must be a non-empty string")

    router = spec.get("router")
    if isinstance(router, dict):
        if router.get("mode") not in {"local-deterministic", "remote"}:
            errors.append(f"{source}: spec.router.mode must be 'local-deterministic' or 'remote'")

    gov = spec.get("governance")
    if isinstance(gov, dict):
        if not _non_empty_str_list(gov.get("requiredStatusChecks")):
            errors.append(f"{source}: spec.governance.requiredStatusChecks must be a non-empty array of strings")
        if "disallowDuplicateRequiredChecks" in gov and not isinstance(gov.get("disallowDuplicateRequiredChecks"), bool):
            errors.append(f"{source}: spec.governance.disallowDuplicateRequiredChecks must be a boolean")

    obs = spec.get("observability")
    if isinstance(obs, dict):
        for field in ("autoHealVar", "telemetryPollVar", "webMonitorWorkflow"):
            if not _non_empty_str(obs.get(field)):
                errors.append(f"{source}: spec.observability.{field} must be a non-empty string")
        if not _non_empty_str_list(obs.get("wifVarsAllOf")):
            errors.append(f"{source}: spec.observability.wifVarsAllOf must be a non-empty array of strings")
        archive = obs.get("transcriptArchive")
        if not isinstance(archive, dict):
            errors.append(f"{source}: spec.observability.transcriptArchive must be an object")
        else:
            if not _non_empty_str(archive.get("configFile")):
                errors.append(f"{source}: spec.observability.transcriptArchive.configFile must be a non-empty string")
            if not isinstance(archive.get("verifyBucket"), bool):
                errors.append(f"{source}: spec.observability.transcriptArchive.verifyBucket must be a boolean")

    delivery = spec.get("delivery")
    if isinstance(delivery, dict):
        if not _non_empty_str_list(delivery.get("requiredBranches")):
            errors.append(f"{source}: spec.delivery.requiredBranches must be a non-empty array of strings")
        if not _non_empty_str(delivery.get("promoteWorkflow")):
            errors.append(f"{source}: spec.delivery.promoteWorkflow must be a non-empty string")
        if "detectOrphanedWorkflows" in delivery and not isinstance(delivery.get("detectOrphanedWorkflows"), bool):
            errors.append(f"{source}: spec.delivery.detectOrphanedWorkflows must be a boolean")

    return errors


def _run_json(cmd: list[str], cwd: Path, timeout: float = 8.0) -> tuple[bool, Any, str]:
    try:
        proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        return False, None, str(error)
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout).strip().splitlines()
        return False, None, detail[0] if detail else f"exit {proc.returncode}"
    text = proc.stdout.strip()
    if not text:
        return True, {}, ""
    try:
        return True, json.loads(text), ""
    except json.JSONDecodeError as error:
        return False, None, f"invalid json: {error}"


def default_gh_api(root: Path, endpoint: str) -> tuple[bool, Any, str]:
    if not shutil.which("gh"):
        return False, None, "gh CLI not installed"
    return _run_json(["gh", "api", endpoint], cwd=root, timeout=8.0)


def default_gcloud_bucket_check(root: Path, bucket: str, project: str | None) -> tuple[str, str]:
    """Return ('exists'|'missing'|'error', detail) without printing credentials."""
    if not shutil.which("gcloud"):
        return "error", "gcloud CLI not installed"
    cmd = ["gcloud", "storage", "buckets", "describe", f"gs://{bucket}", "--format=value(name)"]
    if project:
        cmd.append(f"--project={project}")
    try:
        proc = subprocess.run(cmd, cwd=root, capture_output=True, text=True, timeout=8.0, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        return "error", str(error)
    if proc.returncode == 0:
        return "exists", f"gs://{bucket}"
    stderr = (proc.stderr or proc.stdout).strip()
    if "404" in stderr or "not found" in stderr.lower() or "does not exist" in stderr.lower():
        return "missing", f"gs://{bucket} not found (404)"
    first = stderr.splitlines()[0] if stderr else f"exit {proc.returncode}"
    return "error", first


@dataclass
class LocalSnapshot:
    manifest_errors: list[str]
    skills_errors: list[str]
    log_errors: list[str]
    hooks_installed: bool
    hooks_path: str | None
    providers_read_only: dict[str, dict[str, Any]]
    providers_write: dict[str, dict[str, Any]]
    router_status: dict[str, Any]
    archive_report: dict[str, Any]


def _component(
    namespace: str,
    name: str,
    ready: str,
    status: str,
    reason: str,
    message: str,
    *,
    condition_type: str,
    owner: str = "agent",
    remediation: str | None = None,
) -> dict[str, Any]:
    return {
        "namespace": namespace,
        "name": name,
        "ready": ready,
        "status": status,
        "reason": reason,
        "message": message,
        "conditionType": condition_type,
        "owner": owner,
        "remediation": remediation,
    }


def _latest_run_conclusion(runs_payload: Any) -> tuple[str | None, int | None]:
    if not isinstance(runs_payload, dict):
        return None, None
    runs = runs_payload.get("workflow_runs")
    if not isinstance(runs, list) or not runs:
        return None, None
    first = runs[0]
    if not isinstance(first, dict):
        return None, None
    return first.get("conclusion") or first.get("status"), first.get("id")


def _extract_repo_remote_state(
    root: Path,
    spec: dict[str, Any],
    gh_api: Callable[[Path, str], tuple[bool, Any, str]],
) -> dict[str, Any]:
    """Fetch GitHub API snapshots concurrently with bounded timeouts."""
    ci = spec["ciRunners"]
    obs = spec["observability"]
    delivery = spec["delivery"]
    merge_wf = ci.get("mergeGateWorkflow", "merge-gate.yml")
    monitor_wf = obs["webMonitorWorkflow"]
    promote_wf = delivery["promoteWorkflow"]

    endpoints = {
        "secrets": "repos/{owner}/{repo}/actions/secrets?per_page=100",
        "variables": "repos/{owner}/{repo}/actions/variables?per_page=100",
        "branches": "repos/{owner}/{repo}/branches?per_page=100",
        "workflows": "repos/{owner}/{repo}/actions/workflows?per_page=100",
        "rulesets": "repos/{owner}/{repo}/rulesets?per_page=100",
        "merge_runs": f"repos/{{owner}}/{{repo}}/actions/workflows/{merge_wf}/runs?per_page=1",
        "monitor_runs": f"repos/{{owner}}/{{repo}}/actions/workflows/{monitor_wf}/runs?per_page=1",
        "promote_runs": f"repos/{{owner}}/{{repo}}/actions/workflows/{promote_wf}/runs?per_page=1",
    }
    results: dict[str, tuple[bool, Any, str]] = {}
    with ThreadPoolExecutor(max_workers=len(endpoints)) as pool:
        futures = {key: pool.submit(gh_api, root, ep) for key, ep in endpoints.items()}
        for key, fut in futures.items():
            results[key] = fut.result()

    # Expand active branch rulesets to inspect required status checks.
    ruleset_details: list[dict[str, Any]] = []
    ok_rs, rs_payload, _ = results["rulesets"]
    if ok_rs and isinstance(rs_payload, list):
        ids = [item["id"] for item in rs_payload if isinstance(item, dict) and item.get("enforcement") == "active" and "id" in item]
        if ids:
            with ThreadPoolExecutor(max_workers=min(8, len(ids))) as pool:
                futs = [pool.submit(gh_api, root, f"repos/{{owner}}/{{repo}}/rulesets/{rid}") for rid in ids]
                for fut in futs:
                    ok_one, detail, _ = fut.result()
                    if ok_one and isinstance(detail, dict):
                        ruleset_details.append(detail)
    return {"raw": results, "ruleset_details": ruleset_details}


def observe_agent_system(
    root: Path,
    manifest: dict[str, Any],
    local: LocalSnapshot,
    *,
    offline: bool = False,
    gh_api: Callable[[Path, str], tuple[bool, Any, str]] = default_gh_api,
    gcloud_bucket_check: Callable[[Path, str, str | None], tuple[str, str]] = default_gcloud_bucket_check,
) -> dict[str, Any]:
    """Reconcile desired AgentSystem spec against observed state (read-only)."""
    spec = manifest["spec"]
    meta = manifest["metadata"]
    cp = spec["controlPlane"]
    ci = spec["ciRunners"]
    router_spec = spec["router"]
    gov = spec["governance"]
    obs = spec["observability"]
    delivery = spec["delivery"]

    components: list[dict[str, Any]] = []

    # 1. control-plane/agentctl
    cp_issues: list[str] = []
    if local.manifest_errors:
        cp_issues.append(f"{len(local.manifest_errors)} manifest error(s)")
    if cp["skillsSync"] and local.skills_errors:
        cp_issues.append(f"{len(local.skills_errors)} skill error(s)")
    if local.log_errors:
        cp_issues.append(f"{len(local.log_errors)} JSONL log error(s)")
    if not local.hooks_installed or local.hooks_path != cp["requiredHooksPath"]:
        cp_issues.append(f"git core.hooksPath={local.hooks_path!r} (want {cp['requiredHooksPath']!r})")
    if cp_issues:
        components.append(_component(
            "control-plane", "agentctl", "0/1", "Degraded", "LocalIntegrityFailed",
            "; ".join(cp_issues),
            condition_type="ControlPlaneReady", owner="agent",
            remediation="Run `make hooks`, `scripts/agents/agentctl skills sync`, and `scripts/agents/agentctl heal`.",
        ))
    else:
        components.append(_component(
            "control-plane", "agentctl", "1/1", "Ready", "Healthy",
            "Manifests, skills, JSONL logs, and git hooks are valid.",
            condition_type="ControlPlaneReady",
        ))

    # 2. control-plane/providers
    total_providers = len(local.providers_read_only)
    safe_ro = sorted(p for p, info in local.providers_read_only.items() if info.get("policy_safe"))
    safe_rw = sorted(p for p, info in local.providers_write.items() if info.get("policy_safe"))
    min_safe = cp["minPolicySafeProviders"]
    if len(safe_ro) >= min_safe and len(safe_rw) >= min_safe:
        components.append(_component(
            "control-plane", "providers", f"{len(safe_ro)}/{total_providers}", "Ready", "PolicySafeAvailable",
            f"read-only: {', '.join(safe_ro)}; workspace-write: {', '.join(safe_rw)}",
            condition_type="LocalProvidersReady",
        ))
    else:
        components.append(_component(
            "control-plane", "providers", f"{len(safe_ro)}/{total_providers}", "NotReady", "InsufficientSafeProviders",
            f"Need >= {min_safe} policy-safe provider(s); read-only={safe_ro}, workspace-write={safe_rw}",
            condition_type="LocalProvidersReady", owner="owner",
            remediation="Install and verify at least one policy-safe CLI (`claude`, `codex`, or `agy`).",
        ))

    # 3. control-plane/decision-router
    effective_mode = local.router_status.get("effective_mode", "local-deterministic")
    desired_mode = router_spec["mode"]
    if desired_mode == "local-deterministic":
        components.append(_component(
            "control-plane", "decision-router", "1/1", "Ready", "LocalDeterministic",
            f"mode={effective_mode} (matches desired local-deterministic)",
            condition_type="DecisionRouterReady",
        ))
    elif local.router_status.get("remote_ready"):
        components.append(_component(
            "control-plane", "decision-router", "1/1", "Ready", "RemoteRouterReady",
            f"mode={effective_mode} endpoint={local.router_status.get('resolved_endpoint')}",
            condition_type="DecisionRouterReady",
        ))
    else:
        blockers = local.router_status.get("remote_blockers") or ["remote router not ready"]
        components.append(_component(
            "control-plane", "decision-router", "0/1", "Degraded", "RemoteRouterBlocked",
            "; ".join(blockers),
            condition_type="DecisionRouterReady", owner="owner",
            remediation="Run `scripts/setup/agent_router.sh --enable-remote` or set spec.router.mode=local-deterministic.",
        ))

    # Fetch remote state if online.
    remote = None if offline else _extract_repo_remote_state(root, spec, gh_api)
    bucket_status: tuple[str, str] | None = None
    archive_bucket = (local.archive_report or {}).get("bucket")
    archive_project = (local.archive_report or {}).get("project")
    if not offline and obs["transcriptArchive"]["verifyBucket"] and archive_bucket:
        bucket_name = str(archive_bucket).removeprefix("gs://").split("/", 1)[0]
        bucket_status = gcloud_bucket_check(root, bucket_name, archive_project)

    def _remote_unavailable(namespace: str, name: str, condition_type: str, reason: str, detail: str) -> dict[str, Any]:
        return _component(
            namespace, name, "0/1", "Unknown", reason, detail,
            condition_type=condition_type, owner="agent",
        )

    if offline:
        for ns, name, ctype in (
            ("ci-runners", "agent-implement", "CIRunnersReady"),
            ("ci-runners", "merge-gate", "MergeGateReady"),
            ("ci-runners", "governance", "GovernanceEnforced"),
            ("observability", "web-monitor", "WebMonitorHealthy"),
            ("observability", "fault-intake", "FaultIntakeReady"),
            ("observability", "transcript-archive", "ArchiveStorageReady"),
            ("delivery", "promote-channels", "ReleasePipelineReady"),
            ("delivery", "workflows", "WorkflowsClean"),
        ):
            components.append(_remote_unavailable(ns, name, ctype, "OfflineMode", "Skipped remote probe (--offline)."))
    else:
        assert remote is not None
        raw = remote["raw"]
        ok_sec, sec_payload, sec_err = raw["secrets"]
        ok_var, var_payload, var_err = raw["variables"]
        ok_br, br_payload, br_err = raw["branches"]
        ok_wf, wf_payload, wf_err = raw["workflows"]
        ok_rs, _, rs_err = raw["rulesets"]

        secret_names = (
            {item["name"] for item in sec_payload.get("secrets", []) if isinstance(item, dict) and "name" in item}
            if ok_sec and isinstance(sec_payload, dict) else None
        )
        variables = (
            {item["name"]: str(item.get("value", "")) for item in var_payload.get("variables", []) if isinstance(item, dict) and "name" in item}
            if ok_var and isinstance(var_payload, dict) else None
        )
        branch_names = (
            {item["name"] for item in br_payload if isinstance(item, dict) and "name" in item}
            if ok_br and isinstance(br_payload, list) else None
        )

        # 4. ci-runners/agent-implement
        if secret_names is None:
            components.append(_remote_unavailable("ci-runners", "agent-implement", "CIRunnersReady", "GitHubAPIError", sec_err))
        else:
            auth_present = [s for s in ci["providerAuthSecretsAnyOf"] if s in secret_names]
            app_missing = [s for s in ci["agentAppSecretsAllOf"] if s not in secret_names]
            reasons: list[str] = []
            msgs: list[str] = []
            rems: list[str] = []
            if not auth_present:
                reasons.append("MissingHarnessSecrets")
                msgs.append(f"0/{len(ci['providerAuthSecretsAnyOf'])} provider auth secrets set")
                rems.append("Run one of scripts/human/agents/{login-claude-runner,sync-codex-runner,sync-antigravity-runner}.sh")
            if app_missing:
                reasons.append("MissingAgentApp")
                msgs.append(f"missing {', '.join(app_missing)} (GITHUB_TOKEN PRs skip CI & merge/auto)")
                rems.append("Run scripts/human/github/create-agent-app.sh")
            if reasons:
                components.append(_component(
                    "ci-runners", "agent-implement", "0/1", "NotReady", ",".join(reasons),
                    "; ".join(msgs), condition_type="CIRunnersReady", owner="owner",
                    remediation="; ".join(rems),
                ))
            else:
                components.append(_component(
                    "ci-runners", "agent-implement", "1/1", "Ready", "Configured",
                    f"Auth secrets: {', '.join(auth_present)}; Agent App configured.",
                    condition_type="CIRunnersReady",
                ))

        # 5. ci-runners/merge-gate
        if secret_names is None:
            components.append(_remote_unavailable("ci-runners", "merge-gate", "MergeGateReady", "GitHubAPIError", sec_err))
        else:
            mg_missing = [s for s in ci["mergeGateSecretsAllOf"] if s not in secret_names]
            ok_mg, mg_runs, _ = raw["merge_runs"]
            conclusion, run_id = _latest_run_conclusion(mg_runs) if ok_mg else (None, None)
            if mg_missing:
                components.append(_component(
                    "ci-runners", "merge-gate", "0/1", "NotReady", "MissingMergeGateToken",
                    f"Missing secret(s): {', '.join(mg_missing)}",
                    condition_type="MergeGateReady", owner="owner",
                    remediation="Run `scripts/secrets/rotate.py MERGE_GATE_TOKEN`.",
                ))
            elif conclusion in {"failure", "timed_out", "startup_failure"}:
                components.append(_component(
                    "ci-runners", "merge-gate", "0/1", "Failing", "WorkflowFailed",
                    f"Latest merge-gate run {run_id} ended with {conclusion}.",
                    condition_type="MergeGateReady", owner="agent",
                    remediation=f"Inspect `gh run view {run_id} --log-failed`.",
                ))
            else:
                components.append(_component(
                    "ci-runners", "merge-gate", "1/1", "Ready", "Healthy",
                    f"Secret configured; latest run={conclusion or 'none'}.",
                    condition_type="MergeGateReady",
                ))

        # 6. ci-runners/governance
        if not ok_rs:
            components.append(_remote_unavailable("ci-runners", "governance", "GovernanceEnforced", "GitHubAPIError", rs_err))
        else:
            default_branch = meta["defaultBranch"]
            checks_found: list[str] = []
            for rs in remote["ruleset_details"]:
                inc = rs.get("conditions", {}).get("ref_name", {}).get("include", [])
                if "~DEFAULT_BRANCH" not in inc and f"refs/heads/{default_branch}" not in inc:
                    continue
                for rule in rs.get("rules", []):
                    if rule.get("type") == "required_status_checks":
                        for entry in rule.get("parameters", {}).get("required_status_checks", []):
                            ctx = entry.get("context")
                            if isinstance(ctx, str):
                                checks_found.append(ctx)
            missing_checks = [c for c in gov["requiredStatusChecks"] if c not in checks_found]
            dupes = [c for c, count in Counter(checks_found).items() if count > 1] if gov.get("disallowDuplicateRequiredChecks", True) else []
            if missing_checks or dupes:
                parts: list[str] = []
                if missing_checks:
                    parts.append(f"missing required check(s): {', '.join(missing_checks)}")
                if dupes:
                    parts.append(f"duplicate required check(s): {', '.join(dupes)}")
                components.append(_component(
                    "ci-runners", "governance", "0/1", "Degraded", "RulesetDrift",
                    "; ".join(parts), condition_type="GovernanceEnforced", owner="owner",
                    remediation=f"Update default-branch ({default_branch}) ruleset required status checks.",
                ))
            else:
                components.append(_component(
                    "ci-runners", "governance", "1/1", "Ready", "RulesetAligned",
                    f"Required checks enforced on {default_branch}: {', '.join(gov['requiredStatusChecks'])}.",
                    condition_type="GovernanceEnforced",
                ))

        # 7. observability/web-monitor
        if variables is None:
            components.append(_remote_unavailable("observability", "web-monitor", "WebMonitorHealthy", "GitHubAPIError", var_err))
        else:
            auto_heal = variables.get(obs["autoHealVar"], "")
            ok_mon, mon_runs, _ = raw["monitor_runs"]
            conclusion, run_id = _latest_run_conclusion(mon_runs) if ok_mon else (None, None)
            reasons = []
            msgs = []
            if conclusion in {"failure", "timed_out", "startup_failure"}:
                reasons.append("LiveProbeFailed")
                msgs.append(f"latest {obs['webMonitorWorkflow']} run {run_id} failed")
            if auto_heal != "true":
                reasons.append("AutoHealDisabled")
                msgs.append(f"{obs['autoHealVar']}={auto_heal or 'unset'}")
            if reasons:
                status = "Failing" if "LiveProbeFailed" in reasons else "Degraded"
                rem_items: list[dict[str, str]] = []
                if "LiveProbeFailed" in reasons:
                    rem_items.append({"owner": "agent", "action": f"Inspect `gh run view {run_id} --log-failed` and triage filed heal issue"})
                if auto_heal != "true":
                    rem_items.append({"owner": "owner", "action": "Run `make monitoring` in a terminal to enable AUTO_HEAL_ENABLED"})
                comp = _component(
                    "observability", "web-monitor", "0/1", status, ",".join(reasons),
                    "; ".join(msgs), condition_type="WebMonitorHealthy",
                    owner="owner" if auto_heal != "true" and "LiveProbeFailed" not in reasons else "agent",
                    remediation="; ".join(item["action"] for item in rem_items),
                )
                comp["remediations"] = rem_items
                components.append(comp)
            else:
                components.append(_component(
                    "observability", "web-monitor", "1/1", "Ready", "Healthy",
                    f"{obs['autoHealVar']}=true; latest run={conclusion or 'none'}.",
                    condition_type="WebMonitorHealthy",
                ))

        # 8. observability/fault-intake
        if variables is None:
            components.append(_remote_unavailable("observability", "fault-intake", "FaultIntakeReady", "GitHubAPIError", var_err))
        else:
            missing_wif = [v for v in obs["wifVarsAllOf"] if not variables.get(v)]
            poll_enabled = variables.get(obs["telemetryPollVar"], "")
            if missing_wif:
                components.append(_component(
                    "observability", "fault-intake", "0/1", "NotReady", "MissingWIFVars",
                    f"Missing repo variable(s): {', '.join(missing_wif)} ({obs['telemetryPollVar']}={poll_enabled or 'unset'})",
                    condition_type="FaultIntakeReady", owner="owner",
                    remediation="Run `ENV=production scripts/infra/apply.sh` to restore GCP WIF variables.",
                ))
            elif poll_enabled != "true":
                components.append(_component(
                    "observability", "fault-intake", "0/1", "Suspended", "TelemetryPollDisabled",
                    f"WIF configured, but {obs['telemetryPollVar']}={poll_enabled or 'unset'}.",
                    condition_type="FaultIntakeReady", owner="owner",
                    remediation="Run `make monitoring` to enable TELEMETRY_POLL_ENABLED if pull polling is desired.",
                ))
            else:
                components.append(_component(
                    "observability", "fault-intake", "1/1", "Ready", "Healthy",
                    "GCP WIF variables and telemetry polling are configured.",
                    condition_type="FaultIntakeReady",
                ))

        # 9. observability/transcript-archive
        arch = local.archive_report or {}
        if not arch.get("configured"):
            components.append(_component(
                "observability", "transcript-archive", "0/1", "NotReady", "Unconfigured",
                f"Archive config missing ({obs['transcriptArchive']['configFile']}).",
                condition_type="ArchiveStorageReady", owner="owner",
            ))
        elif bucket_status is not None and bucket_status[0] == "missing":
            unarchived = arch.get("sessions_without_archive", 0)
            components.append(_component(
                "observability", "transcript-archive", "0/1", "NotReady", "BucketNotFound",
                f"{bucket_status[1]} ({unarchived} session(s) unarchived).",
                condition_type="ArchiveStorageReady", owner="owner",
                remediation="Run `scripts/agents/agentctl sessions provision-archive --apply`.",
            ))
        elif bucket_status is not None and bucket_status[0] == "error":
            components.append(_component(
                "observability", "transcript-archive", "0/1", "Unknown", "GCloudCheckFailed",
                bucket_status[1], condition_type="ArchiveStorageReady", owner="owner",
                remediation="Run `gcloud auth login` and verify access to the archive bucket.",
            ))
        else:
            unarchived = arch.get("sessions_without_archive", 0)
            if unarchived:
                components.append(_component(
                    "observability", "transcript-archive", "1/1", "Degraded", "UnarchivedSessions",
                    f"Bucket reachable; {unarchived} session(s) without archive.",
                    condition_type="ArchiveStorageReady", owner="agent",
                    remediation="Run `scripts/agents/agentctl sessions archive` for pending sessions.",
                ))
            else:
                components.append(_component(
                    "observability", "transcript-archive", "1/1", "Ready", "Healthy",
                    f"Bucket {arch.get('bucket')} reachable; all archivable sessions archived.",
                    condition_type="ArchiveStorageReady",
                ))

        # 10. delivery/promote-channels
        if branch_names is None:
            components.append(_remote_unavailable("delivery", "promote-channels", "ReleasePipelineReady", "GitHubAPIError", br_err))
        else:
            missing_branches = [b for b in delivery["requiredBranches"] if b not in branch_names]
            ok_pr, pr_runs, _ = raw["promote_runs"]
            conclusion, run_id = _latest_run_conclusion(pr_runs) if ok_pr else (None, None)
            if missing_branches:
                components.append(_component(
                    "delivery", "promote-channels", "0/1", "Failed", "MissingReleaseBranch",
                    f"Missing branch(es) on origin: {', '.join(missing_branches)} (latest promote run={conclusion or 'none'}).",
                    condition_type="ReleasePipelineReady", owner="owner",
                    remediation=f"Create missing branch(es) on origin: {', '.join(missing_branches)}.",
                ))
            elif conclusion in {"failure", "timed_out", "startup_failure"}:
                components.append(_component(
                    "delivery", "promote-channels", "0/1", "Failed", "PromoteWorkflowFailed",
                    f"Latest {delivery['promoteWorkflow']} run {run_id} ended with {conclusion}.",
                    condition_type="ReleasePipelineReady", owner="agent",
                    remediation=f"Inspect `gh run view {run_id} --log-failed`.",
                ))
            else:
                components.append(_component(
                    "delivery", "promote-channels", "1/1", "Ready", "Healthy",
                    f"All {len(delivery['requiredBranches'])} channel branches exist; latest run={conclusion or 'none'}.",
                    condition_type="ReleasePipelineReady",
                ))

        # 11. delivery/workflows (orphaned active GitHub Actions workflows)
        if not ok_wf or not isinstance(wf_payload, dict):
            components.append(_remote_unavailable("delivery", "workflows", "WorkflowsClean", "GitHubAPIError", wf_err))
        else:
            orphans: list[str] = []
            if delivery.get("detectOrphanedWorkflows", True):
                for wf in wf_payload.get("workflows", []):
                    if not isinstance(wf, dict) or wf.get("state") != "active":
                        continue
                    path = wf.get("path", "")
                    if isinstance(path, str) and path.startswith(".github/workflows/") and not (root / path).exists():
                        orphans.append(f"{path} (id {wf.get('id')})")
            if orphans:
                components.append(_component(
                    "delivery", "workflows", "0/1", "Degraded", "OrphanedActiveWorkflows",
                    f"Active in GitHub API but deleted from repo: {', '.join(orphans)}",
                    condition_type="WorkflowsClean", owner="owner",
                    remediation="Disable orphaned workflow(s) via `gh workflow disable <id>`.",
                ))
            else:
                components.append(_component(
                    "delivery", "workflows", "1/1", "Ready", "Healthy",
                    "All active repository workflow files exist on the current branch.",
                    condition_type="WorkflowsClean",
                ))

    evaluated = [c for c in components if c["status"] != "Unknown"] if offline else components
    ready_count = sum(1 for c in components if c["status"] == "Ready")
    total_count = len(components)
    eval_ready = sum(1 for c in evaluated if c["status"] == "Ready")
    if evaluated and eval_ready == len(evaluated):
        phase = "Ready"
    elif any(c["status"] in {"NotReady", "Failed", "Failing"} for c in evaluated):
        phase = "NotReady"
    else:
        phase = "Degraded"

    conditions = [
        {
            "type": c["conditionType"],
            "status": "True" if c["status"] == "Ready" else ("Unknown" if c["status"] == "Unknown" else "False"),
            "reason": c["reason"],
            "message": c["message"],
            "owner": c["owner"],
            "remediation": c["remediation"],
        }
        for c in components
    ]
    reconcile: dict[str, list[dict[str, str]]] = {"owner": [], "agent": []}
    for c in components:
        if c["status"] in {"Ready", "Unknown"}:
            continue
        if c.get("remediations"):
            for item in c["remediations"]:
                bucket_key = "owner" if item.get("owner") == "owner" else "agent"
                reconcile[bucket_key].append({
                    "component": f"{c['namespace']}/{c['name']}",
                    "reason": c["reason"],
                    "action": item["action"],
                })
        elif c.get("remediation"):
            bucket_key = "owner" if c["owner"] == "owner" else "agent"
            reconcile[bucket_key].append({
                "component": f"{c['namespace']}/{c['name']}",
                "reason": c["reason"],
                "action": c["remediation"],
            })

    return {
        "apiVersion": API_VERSION,
        "kind": KIND,
        "metadata": meta,
        "spec": spec,
        "status": {
            "phase": phase,
            "ready": f"{ready_count}/{total_count}",
            "offline": offline,
            "observedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "components": components,
            "conditions": conditions,
            "reconcile": reconcile,
        },
    }


def render_table(report: dict[str, Any], *, wide: bool = False, namespace: str | None = None) -> str:
    """Render an AgentSystem report in compact kubectl-style columns."""
    components = report["status"]["components"]
    if namespace:
        components = [c for c in components if c["namespace"] == namespace]

    headers = ["NAMESPACE", "NAME", "READY", "STATUS", "REASON"]
    if wide:
        headers.append("MESSAGE")
    rows = [
        [c["namespace"], c["name"], c["ready"], c["status"], c["reason"], *([c["message"]] if wide else [])]
        for c in components
    ]
    widths = [max(len(headers[i]), *(len(r[i]) for r in rows)) if rows else len(headers[i]) for i in range(len(headers))]

    lines = [
        f"{report['kind']}/{report['metadata']['name']}  phase={report['status']['phase']}  ready={report['status']['ready']}"
        + ("  (offline)" if report["status"]["offline"] else ""),
        "",
        "  ".join(headers[i].ljust(widths[i]) for i in range(len(headers))).rstrip(),
    ]
    for row in rows:
        lines.append("  ".join(row[i].ljust(widths[i]) for i in range(len(headers))).rstrip())

    unhealthy = [c for c in components if c["status"] != "Ready" and c["reason"] != "OfflineMode"]
    if unhealthy:
        lines.append("")
        lines.append("Conditions (not ready):")
        for c in unhealthy:
            cond_state = "Unknown" if c["status"] == "Unknown" else "False"
            lines.append(f"  - {c['conditionType']}={cond_state} ({c['reason']}): {c['message']}")

    reconcile = report["status"]["reconcile"]
    owner_steps = [r for r in reconcile["owner"] if not namespace or r["component"].startswith(f"{namespace}/")]
    agent_steps = [r for r in reconcile["agent"] if not namespace or r["component"].startswith(f"{namespace}/")]
    if owner_steps or agent_steps:
        lines.append("")
        lines.append("Reconcile:")
        for step in owner_steps:
            lines.append(f"  [owner] {step['component']}: {step['action']}")
        for step in agent_steps:
            lines.append(f"  [agent] {step['component']}: {step['action']}")
    return "\n".join(lines)
