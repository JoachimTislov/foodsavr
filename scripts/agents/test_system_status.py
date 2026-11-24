#!/usr/bin/env python3
"""Tests for Kubernetes-style declarative AgentSystem manifest and `agentctl status`."""

from __future__ import annotations

import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/agents"))

import system_status as ss  # noqa: E402

MANIFEST_PATH = ROOT / ".agents/system.json"
CLI = ROOT / "scripts/agents/agentctl"
LIVE_RULESET = Path(__file__).with_name("fixtures") / "default-branch-ruleset-25301211.json"


def _load_repo_manifest() -> dict[str, Any]:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def _healthy_local() -> ss.LocalSnapshot:
    return ss.LocalSnapshot(
        manifest_errors=[],
        skills_errors=[],
        log_errors=[],
        hooks_installed=True,
        hooks_path=".githooks",
        providers_read_only={
            "claude": {"policy_safe": True},
            "codex": {"policy_safe": True},
            "vibe": {"policy_safe": False},
        },
        providers_write={
            "claude": {"policy_safe": True},
            "codex": {"policy_safe": True},
            "vibe": {"policy_safe": False},
        },
        router_status={
            "effective_mode": "local-deterministic",
            "remote_ready": False,
            "remote_blockers": ["remote disabled"],
        },
        archive_report={
            "configured": True,
            "bucket": "gs://foodsavr-agent-transcripts/sessions/",
            "project": "foodsavr-prod",
            "sessions_without_archive": 0,
        },
    )


def _healthy_gh_api(root: Path, endpoint: str) -> tuple[bool, Any, str]:
    if endpoint.startswith("repos/{owner}/{repo}/actions/secrets"):
        return True, {
            "secrets": [
                {"name": "CLAUDE_CODE_OAUTH_TOKEN"},
                {"name": "AGENT_APP_PRIVATE_KEY"},
                {"name": "RELEASE_GATE_APP_PRIVATE_KEY"},
            ]
        }, ""
    if endpoint.startswith("repos/{owner}/{repo}/actions/variables"):
        return True, {
            "variables": [
                {"name": "AGENT_APP_ID", "value": "1"},
                {"name": "RELEASE_GATE_APP_ID", "value": "2"},
                {"name": "RELEASE_TOPOLOGY", "value": "full-channels"},
                {"name": "AUTO_HEAL_ENABLED", "value": "true"},
                {"name": "TELEMETRY_POLL_ENABLED", "value": "true"},
                {"name": "GCP_WORKLOAD_IDENTITY_PROVIDER", "value": "projects/1/locations/global/workloadIdentityPools/gh"},
                {"name": "GCP_DEPLOY_SERVICE_ACCOUNT", "value": "deploy@proj.iam.gserviceaccount.com"},
            ]
        }, ""
    if endpoint.startswith("repos/{owner}/{repo}/branches"):
        return True, [{"name": b} for b in ("develop", "daily", "weekly", "stable")], ""
    if endpoint == "repos/{owner}/{repo}":
        return True, {"full_name": "JoachimTislov/foodsavr", "default_branch": "develop"}, ""
    if endpoint.startswith("repos/{owner}/{repo}/git/trees/"):
        return True, {"truncated": False, "tree": [{"path": ".github/workflows/ci.yml", "type": "blob"}]}, ""
    if endpoint.startswith("repos/{owner}/{repo}/actions/workflows?"):
        return True, {"workflows": [{"id": 1, "state": "active", "path": ".github/workflows/ci.yml"}]}, ""
    if endpoint.startswith("repos/{owner}/{repo}/rulesets?"):
        return True, [{"id": 25301211, "enforcement": "active"}], ""
    if endpoint == "repos/{owner}/{repo}/rulesets/25301211":
        return True, json.loads(LIVE_RULESET.read_text(encoding="utf-8")), ""
    if "/runs?" in endpoint:
        return True, {"workflow_runs": [{"id": 9001, "conclusion": "success", "status": "completed"}]}, ""
    return False, None, f"unexpected endpoint {endpoint}"


def _healthy_bucket(_root: Path, bucket: str, _project: str | None) -> tuple[str, str]:
    return "exists", f"gs://{bucket}"


class TestSystemManifestValidation(unittest.TestCase):
    def test_repo_manifest_is_valid(self) -> None:
        manifest = _load_repo_manifest()
        self.assertEqual(ss.validate_system_manifest(manifest, MANIFEST_PATH), [])
        self.assertNotIn("MERGE_GATE_TOKEN", json.dumps(manifest))
        self.assertNotIn("requiredBranches", manifest["spec"]["delivery"])

    def test_rejects_bad_api_version_kind_and_unknown_fields(self) -> None:
        bad = _load_repo_manifest()
        bad["apiVersion"] = "v1"
        bad["kind"] = "Deployment"
        bad["extra"] = True
        bad["metadata"]["unexpected"] = "x"
        bad["spec"]["unknownSection"] = {}
        bad["spec"]["controlPlane"]["minPolicySafeProviders"] = True  # bool must fail int check
        bad["spec"]["router"]["mode"] = "hybrid"
        errors = ss.validate_system_manifest(bad, "bad.json")
        joined = "\n".join(errors)
        self.assertIn("apiVersion", joined)
        self.assertIn("kind", joined)
        self.assertIn("unknown top-level field extra", joined)
        self.assertIn("unknown metadata field unexpected", joined)
        self.assertIn("unknown spec section unknownSection", joined)
        self.assertIn("minPolicySafeProviders", joined)
        self.assertIn("spec.router.mode", joined)

    def test_rejects_non_object_manifest(self) -> None:
        errors = ss.validate_system_manifest([], "list.json")
        self.assertEqual(len(errors), 1)
        self.assertIn("JSON object", errors[0])


class TestObserveAgentSystem(unittest.TestCase):
    def test_all_healthy_remote_and_local(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)

            report = ss.observe_agent_system(
                root,
                _load_repo_manifest(),
                _healthy_local(),
                offline=False,
                gh_api=_healthy_gh_api,
                gcloud_bucket_check=_healthy_bucket,
            )
            self.assertEqual(report["apiVersion"], ss.API_VERSION)
            self.assertEqual(report["kind"], ss.KIND)
            components = {component["name"]: component for component in report["status"]["components"]}
            self.assertEqual(components["governance"]["reason"], "RulesetAligned")
            self.assertEqual(components["merge-gate"]["status"], "Ready")
            self.assertEqual(components["agent-implement"]["status"], "Ready")
            self.assertEqual(components["promote-channels"]["status"], "Ready")
            self.assertEqual(report["status"]["phase"], "Ready")
            self.assertEqual(report["status"]["ready"], "11/11")
            self.assertEqual(report["status"]["reconcile"], {"owner": [], "agent": []})
            table = ss.render_table(report)
            self.assertIn("AgentSystem/foodsavr  phase=Ready  ready=11/11", table)
            self.assertNotIn("Conditions (not ready):", table)
            self.assertNotIn("Reconcile:", table)

    def test_offline_mode_reports_ready_when_local_healthy_and_hides_offline_noise(self) -> None:
        report = ss.observe_agent_system(
            ROOT,
            _load_repo_manifest(),
            _healthy_local(),
            offline=True,
        )
        self.assertEqual(report["status"]["phase"], "Ready")
        self.assertEqual(report["status"]["ready"], "3/11")
        self.assertTrue(report["status"]["offline"])
        remote_comps = [c for c in report["status"]["components"] if c["namespace"] != "control-plane"]
        self.assertTrue(all(c["status"] == "Unknown" and c["reason"] == "OfflineMode" for c in remote_comps))
        table = ss.render_table(report)
        self.assertIn("(offline)", table)
        self.assertNotIn("Conditions (not ready):", table)
        self.assertNotIn("Reconcile:", table)

    def test_local_degraded_control_plane_and_remote_router_blocked(self) -> None:
        manifest = _load_repo_manifest()
        manifest["spec"]["router"]["mode"] = "remote"
        local = _healthy_local()
        local.manifest_errors = ["broken manifest"]
        local.hooks_installed = False
        local.providers_write = {"claude": {"policy_safe": False}}

        report = ss.observe_agent_system(ROOT, manifest, local, offline=True)
        self.assertEqual(report["status"]["phase"], "NotReady")
        by_name = {c["name"]: c for c in report["status"]["components"]}
        self.assertEqual(by_name["agentctl"]["reason"], "LocalIntegrityFailed")
        self.assertEqual(by_name["providers"]["reason"], "InsufficientSafeProviders")
        self.assertEqual(by_name["decision-router"]["reason"], "RemoteRouterBlocked")
        table = ss.render_table(report, namespace="control-plane", wide=True)
        self.assertIn("MESSAGE", table)
        self.assertIn("Conditions (not ready):", table)
        self.assertIn("[agent] control-plane/agentctl:", table)
        self.assertIn("[owner] control-plane/providers:", table)
        self.assertIn("[owner] control-plane/decision-router:", table)
        self.assertNotIn("ci-runners", table)

    def test_unhealthy_remote_matrix_and_split_owner_agent_remediation(self) -> None:
        def unhealthy_gh(root: Path, endpoint: str) -> tuple[bool, Any, str]:
            if endpoint.startswith("repos/{owner}/{repo}/actions/secrets"):
                return True, {"secrets": []}, ""
            if endpoint.startswith("repos/{owner}/{repo}/actions/variables"):
                return True, {"variables": [{"name": "RELEASE_TOPOLOGY", "value": "full-channels"}]}, ""
            if endpoint.startswith("repos/{owner}/{repo}/branches"):
                return True, [{"name": "develop"}, {"name": "daily"}], ""
            if endpoint.startswith("repos/{owner}/{repo}/actions/workflows?"):
                return True, {
                    "workflows": [
                        {"id": 999, "state": "active", "path": ".github/workflows/deleted-orphan.yml"},
                    ]
                }, ""
            if endpoint.startswith("repos/{owner}/{repo}/rulesets?"):
                return True, [{"id": 7, "enforcement": "active"}], ""
            if endpoint == "repos/{owner}/{repo}/rulesets/7":
                return True, {
                    "id": 7,
                    "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"]}},
                    "rules": [
                        {
                            "type": "required_status_checks",
                            "parameters": {
                                "required_status_checks": [
                                    {"context": "Decide whether to run CI"},
                                    {"context": "Check & Test"},
                                    {"context": "Detect changed areas"},
                                    {"context": "Detect changed areas"},
                                ]
                            },
                        }
                    ],
                }, ""
            if "web-monitor.yml/runs" in endpoint:
                return True, {"workflow_runs": [{"id": 5555, "conclusion": "failure"}]}, ""
            if "/runs?" in endpoint:
                return True, {"workflow_runs": [{"id": 4444, "conclusion": "failure"}]}, ""
            return _healthy_gh_api(root, endpoint)

        def missing_bucket(_root: Path, bucket: str, _project: str | None) -> tuple[str, str]:
            return "missing", f"gs://{bucket} not found (404)"

        local = _healthy_local()
        local.archive_report["sessions_without_archive"] = 2

        with tempfile.TemporaryDirectory() as tmpdir:
            report = ss.observe_agent_system(
                Path(tmpdir),
                _load_repo_manifest(),
                local,
                offline=False,
                gh_api=unhealthy_gh,
                gcloud_bucket_check=missing_bucket,
            )

        self.assertEqual(report["status"]["phase"], "NotReady")
        self.assertEqual(report["status"]["ready"], "3/11")
        by_name = {c["name"]: c for c in report["status"]["components"]}
        self.assertEqual(by_name["agent-implement"]["reason"], "MissingHarnessSecrets,MissingAgentApp")
        self.assertEqual(by_name["merge-gate"]["reason"], "MissingReleaseGateApp")
        self.assertEqual(by_name["governance"]["reason"], "RulesetDrift")
        self.assertIn("Validation result", by_name["governance"]["message"])
        self.assertIn("Detect changed areas", by_name["governance"]["message"])
        self.assertEqual(by_name["web-monitor"]["reason"], "LiveProbeFailed,AutoHealDisabled")
        self.assertEqual(by_name["fault-intake"]["reason"], "MissingWIFVars")
        self.assertEqual(by_name["transcript-archive"]["reason"], "BucketNotFound")
        self.assertEqual(by_name["promote-channels"]["reason"], "MissingReleaseBranch")
        self.assertIn("Missing branch(es) on origin: weekly, stable (", by_name["promote-channels"]["message"])
        self.assertEqual(by_name["workflows"]["reason"], "OrphanedActiveWorkflows")

        # Verify web-monitor splits its two remediations between [agent] and [owner].
        owner_rems = report["status"]["reconcile"]["owner"]
        agent_rems = report["status"]["reconcile"]["agent"]
        self.assertTrue(any(r["component"] == "observability/web-monitor" and "AUTO_HEAL_ENABLED" in r["action"] for r in owner_rems))
        self.assertTrue(any(r["component"] == "observability/web-monitor" and "5555" in r["action"] for r in agent_rems))

        table = ss.render_table(report)
        self.assertIn("[owner] observability/web-monitor:", table)
        self.assertIn("[agent] observability/web-monitor:", table)

    def test_release_status_uses_the_active_topology(self) -> None:
        for topology, branches in (("single", ["develop"]), ("two-stage", ["develop", "stable"])):
            with self.subTest(topology=topology):
                def gh(root: Path, endpoint: str) -> tuple[bool, Any, str]:
                    if "/actions/variables?" in endpoint:
                        ok, payload, error = _healthy_gh_api(root, endpoint)
                        for variable in payload["variables"]:
                            if variable["name"] == "RELEASE_TOPOLOGY":
                                variable["value"] = topology
                        return ok, payload, error
                    if "/branches?" in endpoint:
                        return True, [{"name": branch} for branch in branches], ""
                    return _healthy_gh_api(root, endpoint)

                report = ss.observe_agent_system(
                    ROOT, _load_repo_manifest(), _healthy_local(), gh_api=gh, gcloud_bucket_check=_healthy_bucket,
                )
                component = next(c for c in report["status"]["components"] if c["name"] == "promote-channels")
                self.assertEqual(component["status"], "Ready")

    def test_only_active_orphans_need_owner_action(self) -> None:
        for state, reason in (("active", "OrphanedActiveWorkflows"), ("disabled_manually", "Healthy")):
            with self.subTest(state=state):
                def gh(root: Path, endpoint: str) -> tuple[bool, Any, str]:
                    if "/actions/workflows?" in endpoint:
                        return True, {"workflows": [{
                            "id": 234416953,
                            "name": "Flutter Analyze",
                            "path": ".github/workflows/flutter-analyze.yml",
                            "state": state,
                        }]}, ""
                    return _healthy_gh_api(root, endpoint)

                report = ss.observe_agent_system(
                    ROOT, _load_repo_manifest(), _healthy_local(), gh_api=gh, gcloud_bucket_check=_healthy_bucket,
                )
                component = next(c for c in report["status"]["components"] if c["name"] == "workflows")
                self.assertEqual(component["reason"], reason)
                actions = report["status"]["reconcile"]["owner"]
                if state == "active":
                    self.assertIn("Flutter Analyze", component["message"])
                    self.assertEqual(actions, [{
                        "component": "delivery/workflows",
                        "reason": "OrphanedActiveWorkflows",
                        "action": "Run `make disable-orphaned-workflows`.",
                    }])
                else:
                    self.assertEqual(actions, [])

    def test_cli_offline_status_json_and_strict(self) -> None:
        proc = subprocess.run(
            [str(CLI), "status", "--offline", "-o", "json"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["apiVersion"], ss.API_VERSION)
        self.assertEqual(payload["kind"], ss.KIND)
        self.assertTrue(payload["status"]["offline"])
        self.assertEqual(len(payload["status"]["components"]), 11)

        strict_bad = copy.deepcopy(_load_repo_manifest())
        strict_bad["spec"]["router"]["mode"] = "remote"
        with tempfile.TemporaryDirectory() as tmpdir:
            bad_manifest = Path(tmpdir) / "system.json"
            bad_manifest.write_text(json.dumps(strict_bad), encoding="utf-8")
            proc_strict = subprocess.run(
                [str(CLI), "status", "--offline", "--strict", "--manifest", str(bad_manifest)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(proc_strict.returncode, 1)
            self.assertIn("decision-router — degraded.", proc_strict.stdout)
            self.assertNotIn("\nReconcile:", proc_strict.stdout)


if __name__ == "__main__":
    unittest.main()
