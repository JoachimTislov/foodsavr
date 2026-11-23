#!/usr/bin/env python3
"""Adaptive PR review classifier, review/incident history store, and bisect learner.

Connects PR risk classification, head-bound review attestation, post-merge incident
investigation, and dual-level git bisect learning to the merge gate (ADR 0006).
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/agents"))
import event_log  # noqa: E402

DEFAULT_EVENTS = ROOT / ".agents/events"
DEFAULT_HISTORY = ROOT / ".agents/reviews/history.jsonl"
DEFAULT_SESSIONS = ROOT / ".agents/sessions/index.jsonl"
DEFAULT_LEDGER = ROOT / ".agents/ledger.jsonl"
DEFAULT_ROUTER = ROOT / ".agents/runners/router.json"
DEFAULT_WORKFLOW = ROOT / ".agents/workflows/integrate-pr.json"

DEPENDABOT = "dependabot"
TRUSTED_ASSOCIATIONS = frozenset({"OWNER", "MEMBER", "COLLABORATOR"})
DEFAULT_TRUSTED_BOTS = frozenset({DEPENDABOT, "github-actions"})

TIER_ORDER: tuple[str, ...] = ("exempt", "fast", "balanced", "deep", "human")
TIER_RANK: dict[str, int] = {tier: idx for idx, tier in enumerate(TIER_ORDER)}
WORKFLOW_TIER_MAP: dict[str, str] = {
    "exempt": "fast",
    "fast": "fast",
    "balanced": "balanced",
    "deep": "deep",
    "human": "deep",
}

ONE_WAY = re.compile(r"\*\*Door:\*\*\s*one-way", re.IGNORECASE)
BUMP = re.compile(
    r"\bfrom v?(\d+)\.(\d+)(?:\.(\d+))?\S* to v?(\d+)\.(\d+)(?:\.(\d+))?",
    re.IGNORECASE,
)
ATTESTATION_RE = re.compile(r"<!--\s*agent-review:\s*(\{.*?\})\s*-->", re.DOTALL)
# Only merge/squash markers name a PR; a bare "#N" in a body is usually an issue reference.
PR_NUMBER_RE = re.compile(r"(?:Merge pull request #(\d+)|\(#(\d+)\))", re.IGNORECASE)
VERDICT_RE = re.compile(r"VERDICT:\s*(APPROVE|CHANGES_REQUESTED)\b")
SESSION_TRAILER_RE = re.compile(r"^Agent-Session:\s*(\S+)\s*$", re.MULTILINE | re.IGNORECASE)

DEPENDENCY_FILES = frozenset({
    "pubspec.yaml",
    "pubspec.lock",
    "package.json",
    "package-lock.json",
    "requirements.txt",
    "Pipfile",
    "Pipfile.lock",
    "Gemfile",
    "Gemfile.lock",
    "Cargo.toml",
    "Cargo.lock",
    "go.mod",
    "go.sum",
})

TIER_DEFAULT_MODELS: dict[str, list[str]] = {
    "exempt": [],
    "fast": ["gemini-3.8-flash", "claude-haiku-5-5", "opencode/claude-haiku-5-5"],
    "balanced": ["gemini-4-neon", "claude-sonnet-5-5", "opencode/claude-sonnet-5-5", "mistral-large-3"],
    "deep": ["gpt-6.2-sol", "claude-opus-5-5", "gemini-4-argon", "gemini-4-hydrogen"],
    "human": ["claude-opus-5-5", "gemini-4-argon", "gpt-6.2-sol"],
}

TIER_AXES: dict[str, list[str]] = {
    "exempt": [],
    "fast": ["standards"],
    "balanced": ["standards", "spec"],
    "deep": ["standards", "spec"],
    "human": ["standards", "spec", "human-approval"],
}


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def isolated_git_env() -> dict[str, str]:
    """Strip GIT_* hook environment variables so commands target the requested repository."""
    return {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}


def normalize_bot(login: str) -> str:
    cleaned = (login or "").strip().lower()
    return cleaned[:-5] if cleaned.endswith("[bot]") else cleaned


def trusted_bot_set(extra: list[str] | set[str] | frozenset[str] | None = None) -> frozenset[str]:
    bots = set(DEFAULT_TRUSTED_BOTS)
    raw_items = [
        os.environ.get("AGENT_APP_SLUG", ""),
        *os.environ.get("TRUSTED_BOTS", "").split(","),
        *(extra or []),
    ]
    for raw in raw_items:
        normalized = normalize_bot(raw)
        if normalized:
            bots.add(normalized)
    return frozenset(bots)


def is_trusted_actor(
    author: str,
    bot: bool = False,
    author_association: str = "NONE",
    fork: bool = False,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
) -> bool:
    if fork or not author:
        return False
    if bot or author.strip().lower().endswith("[bot]"):
        return normalize_bot(author) in trusted_bots
    if owner and author.strip().lower() == owner.strip().lower():
        return True
    return author_association in TRUSTED_ASSOCIATIONS


def is_human_maintainer(
    author: str,
    bot: bool = False,
    author_association: str = "NONE",
    owner: str = "",
) -> bool:
    if not author or bot or author.strip().lower().endswith("[bot]"):
        return False
    if owner and author.strip().lower() == owner.strip().lower():
        return True
    return author_association in TRUSTED_ASSOCIATIONS


def bump_kind(title: str) -> str | None:
    match = BUMP.search(title or "")
    if not match:
        return None
    old = [int(part or 0) for part in match.groups()[:3]]
    new = [int(part or 0) for part in match.groups()[3:]]
    if new[0] != old[0] or (old[0] == 0 and new[1] != old[1]):
        return "major"
    return "minor" if new[1] != old[1] else "patch"


def _norm_path(file_path: str) -> str:
    cleaned = (file_path or "").strip()
    while cleaned.startswith("./"):
        cleaned = cleaned[2:]
    return cleaned.lstrip("/")


def infer_area(file_path: str) -> str:
    norm = _norm_path(file_path)
    if not norm:
        return "root"
    if norm.startswith(".github/workflows/"):
        return ".github/workflows"
    if norm.startswith(".github/actions/"):
        return ".github/actions"
    if norm.startswith(".agents/policies/"):
        return ".agents/policies"
    if norm.startswith(".agents/runners/"):
        return ".agents/runners"
    if norm.startswith(".agents/workflows/"):
        return ".agents/workflows"
    if norm.startswith(".agents/skills/"):
        return ".agents/skills"
    if norm.startswith(".agents/reviews/"):
        return ".agents/reviews"
    if norm.startswith(".agents/"):
        return ".agents"
    if norm.startswith("scripts/github/"):
        return "scripts/github"
    if norm.startswith("scripts/agents/"):
        return "scripts/agents"
    if norm.startswith("scripts/secrets/"):
        return "scripts/secrets"
    if norm.startswith("scripts/human/"):
        return "scripts/human"
    if norm.startswith("scripts/ci/"):
        return "scripts/ci"
    if norm.startswith("scripts/docs/"):
        return "scripts/docs"
    if norm.startswith("scripts/"):
        return "scripts"
    if norm.startswith("specs/source-of-truth/decisions/"):
        return "specs/source-of-truth/decisions"
    if norm.startswith("specs/"):
        return "specs"
    if norm.startswith(("docs/", "doc/")):
        return "docs"
    if norm.startswith("infra/"):
        return "infra"
    if norm.startswith("packages/"):
        parts = norm.split("/")
        return "/".join(parts[:2]) if len(parts) >= 2 else "packages"
    if norm.startswith("lib/"):
        parts = norm.split("/")
        return "/".join(parts[:2]) if len(parts) >= 2 else "lib"
    if norm.startswith(("test/", "integration_test/", "test_driver/")):
        return "test"
    if norm.startswith("assets/translations/"):
        return "assets/translations"
    if Path(norm).name in DEPENDENCY_FILES:
        return "dependencies"
    parts = norm.split("/")
    return parts[0] if len(parts) > 1 else "root"


def infer_areas(files: list[str]) -> list[str]:
    return sorted({infer_area(path) for path in files if path and path.strip()})


def is_doc_or_test_file(file_path: str) -> bool:
    norm = _norm_path(file_path)
    name = Path(norm).name
    if norm.startswith(("docs/", "doc/", "test/", "integration_test/")):
        return True
    if norm.endswith(".md") and not norm.startswith((".agents/policies/", "specs/source-of-truth/decisions/")):
        return True
    if name.startswith("test_") and name.endswith(".py"):
        return True
    if name.endswith("_test.dart"):
        return True
    return False


def is_critical_path(file_path: str) -> bool:
    norm = _norm_path(file_path)
    if norm.startswith((
        ".github/workflows/",
        ".github/actions/",
        ".githooks/",
        ".agents/policies/",
        ".agents/runners/",
        ".agents/workflows/",
        ".agents/reviews/",
        "scripts/secrets/",
        "scripts/human/",
        "scripts/github/",
        "scripts/agents/",
        "infra/",
        "specs/source-of-truth/decisions/",
    )):
        return True
    if norm in {"firestore.rules", "firebase.json", "specs/source-of-truth/data-model.md", "specs/source-of-truth/architecture.md"}:
        return True
    lowered = norm.lower()
    if any(token in lowered for token in ("secret", "auth", "security", "schema", "migration", "permission")):
        return True
    return False


def infer_risk_signatures(
    *,
    title: str = "",
    body: str = "",
    author: str = "",
    bot: bool = False,
    author_association: str = "NONE",
    fork: bool = False,
    labels: set[str] | list[str] = (),
    files: list[str] | tuple[str, ...] = (),
    additions: int = 0,
    deletions: int = 0,
    changed_files: int = 0,
    files_truncated: bool = False,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
) -> list[str]:
    label_set = {str(item).strip().lower() for item in labels if str(item).strip()}
    file_list = [str(f).strip() for f in files if str(f).strip()]
    effective_changed = max(changed_files, len(file_list))
    total_lines = max(0, additions) + max(0, deletions)
    is_dep = (bot or author.strip().lower().endswith("[bot]")) and normalize_bot(author) == DEPENDABOT
    bump = bump_kind(title)

    signatures: list[str] = []
    if ONE_WAY.search(body or "") or "door/one-way" in label_set:
        signatures.append("one-way-door")
    if fork:
        signatures.append("fork-pr")
    if not is_trusted_actor(author, bot=bot, author_association=author_association, fork=fork, owner=owner, trusted_bots=trusted_bots):
        signatures.append("untrusted-author")
    if files_truncated or effective_changed > 100:
        signatures.append("files-truncated")
    if label_set & {"review/human", "security/critical", "human-only"}:
        signatures.append("human-label")

    for path in file_list:
        norm = _norm_path(path)
        lowered = norm.lower()
        if norm.startswith((".github/workflows/", ".github/actions/", ".githooks/", "scripts/ci/")):
            signatures.append("workflow-ci")
        if norm.startswith((".agents/policies/", ".agents/runners/", ".agents/workflows/", ".agents/reviews/", "scripts/agents/", "scripts/github/")):
            signatures.append("agent-control-plane")
        if norm.startswith(("scripts/secrets/", "scripts/human/")) or norm == "firestore.rules" or any(
            kw in lowered for kw in ("secret", "auth", "security", "permission", "token")
        ):
            signatures.append("security-secrets")
        if norm.startswith(("infra/", "specs/source-of-truth/decisions/")) or norm in {
            "firebase.json",
            "specs/source-of-truth/data-model.md",
            "specs/source-of-truth/architecture.md",
        } or any(kw in lowered for kw in ("schema", "data-model", "migration", "database")):
            signatures.append("schema-data-model")

    if any("security" in lbl or "breaking" in lbl for lbl in label_set):
        signatures.append("security-secrets")

    if is_dep and bump == "major":
        signatures.append("dependabot-major")
    elif is_dep and bump in {"patch", "minor"}:
        signatures.append("dependabot-minor-patch")

    # Determine functional code areas (collapse docs/tests when checking multi-area code risk)
    code_areas = {
        infer_area(f).split("/")[0]
        for f in file_list
        if not is_doc_or_test_file(f)
    }
    if len(code_areas) >= 2:
        signatures.append("multi-area")
    if total_lines > 300 or effective_changed > 10:
        signatures.append("large-diff")

    has_critical = any(is_critical_path(f) for f in file_list) or bool(
        set(signatures) & {
            "one-way-door", "fork-pr", "untrusted-author", "files-truncated", "human-label",
            "workflow-ci", "agent-control-plane", "security-secrets", "schema-data-model",
            "dependabot-major", "multi-area", "large-diff",
        }
    )
    if not has_critical:
        all_docs_or_tests = bool(file_list) and all(is_doc_or_test_file(f) for f in file_list)
        narrow_change = effective_changed <= 2 and total_lines <= 80
        if all_docs_or_tests or narrow_change:
            signatures.append("localized-docs-or-tests")

    return list(dict.fromkeys(signatures))


def recommend_static_checks_for_files(files: list[str], extra_checks: list[str] | None = None) -> list[str]:
    checks: list[str] = list(extra_checks or [])
    for path in files:
        norm = _norm_path(path)
        if norm.startswith((".github/workflows/", ".github/actions/")):
            checks.append("actionlint")
        if norm.startswith((".agents/", "scripts/agents/", "scripts/github/", "scripts/secrets/", "scripts/human/", "scripts/ci/")):
            checks.append("python3 scripts/ci/local_ci.py --group agents")
        if norm.startswith(("specs/", "docs/", "doc/")) or norm.endswith(".md") or norm == "mkdocs.yml":
            checks.append("python3 scripts/ci/local_ci.py --group docs")
        if norm.endswith(".dart") or norm.startswith(("lib/", "test/", "packages/", "integration_test/", "assets/translations/")) or Path(norm).name in {"pubspec.yaml", "pubspec.lock"}:
            checks.append("flutter analyze --fatal-infos --fatal-warnings --no-pub")
            checks.append("dart run scripts/ci/run_tests.dart")
        if norm.endswith(".jsonl") or norm.startswith(("log/", "logs/")):
            checks.append("python3 scripts/agents/check_logs.py")
    if not checks:
        checks.append("python3 scripts/ci/local_ci.py")
    return list(dict.fromkeys(checks))


def load_history(path: Path = DEFAULT_HISTORY) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    content = path.read_text(encoding="utf-8")
    if not content.strip():
        return []
    records: list[dict[str, Any]] = []
    for number, line in enumerate(content.splitlines(), 1):
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(f"{path}:{number}: invalid JSON: {error}") from error
        if not isinstance(item, dict):
            raise ValueError(f"{path}:{number}: record must be a JSON object")
        records.append(item)
    return records


def load_log(path: Path, stream: str, events_dir: Path | None = None) -> list[dict[str, Any]]:
    """Legacy log file plus the per-event files of `stream` (#397); events apply to the repository logs only."""
    rows = load_history(path) if path.exists() else []
    if events_dir is None and path in (DEFAULT_SESSIONS, DEFAULT_LEDGER):
        events_dir = DEFAULT_EVENTS
    if events_dir is not None:
        rows += [{k: v for k, v in row.items() if k != "stream"} for row in event_log.read_events(events_dir, stream)]
    return rows


def validate_history_record(record: dict[str, Any]) -> None:
    if not isinstance(record, dict):
        raise ValueError("history record must be a dict")
    rec_type = record.get("type")
    if rec_type not in {"review", "incident"}:
        raise ValueError(f"history record type must be 'review' or 'incident', got {rec_type!r}")
    if not isinstance(record.get("timestamp"), str) or not record["timestamp"].strip():
        raise ValueError("history record requires non-empty timestamp")
    if rec_type == "review":
        if not isinstance(record.get("pr"), int) or isinstance(record.get("pr"), bool):
            raise ValueError("review record requires integer 'pr'")
        if not isinstance(record.get("head_sha"), str) or not record["head_sha"].strip():
            raise ValueError("review record requires non-empty 'head_sha'")
        if record.get("review_tier") not in TIER_RANK:
            raise ValueError(f"invalid review_tier: {record.get('review_tier')!r}")
        if record.get("required_tier") not in TIER_RANK:
            raise ValueError(f"invalid required_tier: {record.get('required_tier')!r}")
    elif rec_type == "incident":
        if not isinstance(record.get("incident_id"), str) or not record["incident_id"].strip():
            raise ValueError("incident record requires non-empty 'incident_id'")
        if not isinstance(record.get("culprit_commit"), str) or not record["culprit_commit"].strip():
            raise ValueError("incident record requires non-empty 'culprit_commit'")
        if record.get("recommended_tier") not in TIER_RANK:
            raise ValueError(f"invalid recommended_tier: {record.get('recommended_tier')!r}")


def append_history_record(record: dict[str, Any], path: Path = DEFAULT_HISTORY) -> dict[str, Any]:
    if path.suffix != ".jsonl":
        raise ValueError(f"{path}: history store must use .jsonl")
    validate_history_record(record)
    path.parent.mkdir(parents=True, exist_ok=True)
    serialized = json.dumps(record, sort_keys=True, allow_nan=False, ensure_ascii=False)
    if "\n" in serialized or "\r" in serialized:
        raise ValueError("serialized JSONL record must be single-line")
    needs_separator = False
    if path.exists() and path.stat().st_size:
        with path.open("rb") as existing:
            existing.seek(-1, os.SEEK_END)
            needs_separator = existing.read(1) != b"\n"
    with path.open("a", encoding="utf-8") as handle:
        handle.write(("\n" if needs_separator else "") + serialized + "\n")
        handle.flush()
    return record


@dataclass
class Classification:
    pr: int
    head_sha: str
    base_tier: str
    required_tier: str
    escalated: bool
    escalated_from: str | None
    escalation_reasons: list[str]
    reasons: list[str]
    risk_signatures: list[str]
    areas: list[str]
    files: list[str]
    axes: list[str]
    work_type: str
    recommended_models: list[str]
    recommended_static_checks: list[str]
    requires_human_approval: bool
    auto_merge_eligible: bool
    matching_incidents: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "pr": self.pr,
            "head_sha": self.head_sha,
            "base_tier": self.base_tier,
            "required_tier": self.required_tier,
            "escalated": self.escalated,
            "escalated_from": self.escalated_from,
            "escalation_reasons": self.escalation_reasons,
            "reasons": self.reasons,
            "risk_signatures": self.risk_signatures,
            "areas": self.areas,
            "files": self.files,
            "axes": self.axes,
            "work_type": self.work_type,
            "recommended_models": self.recommended_models,
            "recommended_static_checks": self.recommended_static_checks,
            "requires_human_approval": self.requires_human_approval,
            "auto_merge_eligible": self.auto_merge_eligible,
            "matching_incidents": self.matching_incidents,
        }


def _models_for_tier(tier: str, router: dict[str, Any] | None = None) -> list[str]:
    if tier == "exempt":
        return []
    router_tiers = ((router or {}).get("model_tiers") or {})
    if tier == "deep":
        models = list(TIER_DEFAULT_MODELS["deep"])
        for m in (router_tiers.get("deep") or {}).get("models", []):
            if m not in models:
                models.append(m)
        return models
    if tier in router_tiers and isinstance(router_tiers[tier].get("models"), list):
        return list(router_tiers[tier]["models"])
    return list(TIER_DEFAULT_MODELS.get(tier, TIER_DEFAULT_MODELS["balanced"]))


def classify_pr(
    *,
    number: int = 0,
    title: str = "",
    body: str = "",
    author: str = "",
    bot: bool = False,
    author_association: str = "NONE",
    draft: bool = False,
    fork: bool = False,
    head_sha: str = "",
    labels: set[str] | list[str] = (),
    files: list[str] | tuple[str, ...] = (),
    additions: int = 0,
    deletions: int = 0,
    changed_files: int = 0,
    files_truncated: bool = False,
    rollup: str | None = None,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
    history: list[dict[str, Any]] | None = None,
    history_path: Path | None = DEFAULT_HISTORY,
    router: dict[str, Any] | None = None,
) -> Classification:
    """Compute a PR's adaptive review tier with history-driven escalation."""
    file_list = [str(f).strip() for f in files if str(f).strip()]
    areas = infer_areas(file_list)
    signatures = infer_risk_signatures(
        title=title,
        body=body,
        author=author,
        bot=bot,
        author_association=author_association,
        fork=fork,
        labels=labels,
        files=file_list,
        additions=additions,
        deletions=deletions,
        changed_files=changed_files,
        files_truncated=files_truncated,
        owner=owner,
        trusted_bots=trusted_bots,
    )
    sig_set = set(signatures)
    reasons: list[str] = []

    is_dep = (bot or author.strip().lower().endswith("[bot]")) and normalize_bot(author) == DEPENDABOT
    bump = bump_kind(title)
    trusted = is_trusted_actor(
        author, bot=bot, author_association=author_association, fork=fork, owner=owner, trusted_bots=trusted_bots,
    )

    if sig_set & {"one-way-door", "fork-pr", "untrusted-author", "files-truncated", "human-label"}:
        base_tier = "human"
        if "one-way-door" in sig_set:
            reasons.append("PR declares a one-way door")
        if "fork-pr" in sig_set:
            reasons.append("cross-repository fork PR requires human review")
        if "untrusted-author" in sig_set:
            reasons.append(f"author {author or 'unknown'} is not trusted for autonomous review")
        if "files-truncated" in sig_set:
            reasons.append("changed file list exceeds 100-file inspection bound")
        if "human-label" in sig_set:
            reasons.append("PR carries a label requiring human approval")
    elif sig_set & {
        "workflow-ci", "agent-control-plane", "security-secrets",
        "schema-data-model", "dependabot-major", "multi-area", "large-diff",
    }:
        base_tier = "deep"
        if "workflow-ci" in sig_set:
            reasons.append("touches CI workflows, actions, or hooks")
        if "agent-control-plane" in sig_set:
            reasons.append("touches agent policies, runners, or GitHub automation scripts")
        if "security-secrets" in sig_set:
            reasons.append("touches secrets, auth, security rules, or human setup wizards")
        if "schema-data-model" in sig_set:
            reasons.append("touches infrastructure, architecture/ADRs, or data-model schemas")
        if "dependabot-major" in sig_set:
            reasons.append("Dependabot major version bump requires deep review")
        if "multi-area" in sig_set:
            reasons.append(f"spans multiple functional areas ({', '.join(areas)})")
        if "large-diff" in sig_set:
            reasons.append(f"large diff ({additions + deletions} lines across {max(changed_files, len(file_list))} file(s))")
    elif (
        is_dep
        and trusted
        and bump in {"patch", "minor"}
        and rollup != "FAILURE"
    ):
        base_tier = "exempt"
        reasons.append(f"trusted Dependabot {bump} bump with no critical path changes")
    elif "localized-docs-or-tests" in sig_set:
        base_tier = "fast"
        reasons.append("small, localized low-risk change (docs, tests, or narrow non-critical file)")
    else:
        base_tier = "balanced"
        reasons.append("moderate single-area change")

    if history is None:
        history = load_history(history_path) if history_path and history_path.exists() else []

    required_tier = base_tier
    escalation_reasons: list[str] = []
    matching_incidents: list[str] = []
    static_checks: list[str] = []

    file_set = set(file_list)
    area_set = set(areas)
    matchable_sigs = sig_set - {"localized-docs-or-tests", "dependabot-minor-patch"}

    for record in history:
        if not isinstance(record, dict) or record.get("type") != "incident":
            continue
        inc_files = {str(f).strip() for f in record.get("files", []) if str(f).strip()}
        inc_areas = {str(a).strip() for a in record.get("areas", []) if str(a).strip()}
        inc_sigs = {
            str(s).strip()
            for s in record.get("risk_signatures", [])
            if str(s).strip() and str(s).strip() not in {"localized-docs-or-tests", "dependabot-minor-patch"}
        }

        matched_files = sorted(file_set & inc_files)
        matched_areas = sorted(area_set & inc_areas)
        matched_sigs = sorted(matchable_sigs & inc_sigs)
        # A lone broad area or a lone shared signature must not escalate unrelated PRs:
        # require a file overlap, or an area and a signature overlap together.
        if not (matched_files or (matched_areas and matched_sigs)):
            continue

        inc_id = str(record.get("incident_id") or "incident")
        inc_pr = record.get("pr")
        culprit = str(record.get("culprit_commit") or "")[:7]
        orig_tier = str(record.get("original_review_tier") or "fast")
        rec_tier = str(record.get("recommended_tier") or "")

        if rec_tier not in TIER_RANK:
            rec_tier = "human" if orig_tier in {"deep", "human"} else "deep"
        if orig_tier in {"exempt", "fast", "balanced"} and TIER_RANK[rec_tier] < TIER_RANK["deep"]:
            rec_tier = "deep"
        elif orig_tier == "deep" and TIER_RANK[rec_tier] < TIER_RANK["human"]:
            rec_tier = "human"

        matching_incidents.append(inc_id)
        for chk in record.get("recommended_static_checks", []):
            if isinstance(chk, str) and chk.strip() and chk.strip() not in static_checks:
                static_checks.append(chk.strip())

        overlap_desc = (
            f"files {matched_files}" if matched_files
            else f"areas {matched_areas}" if matched_areas
            else f"signatures {matched_sigs}"
        )
        if TIER_RANK[rec_tier] > TIER_RANK[required_tier]:
            required_tier = rec_tier
        escalation_reasons.append(
            f"{inc_id} (PR #{inc_pr if inc_pr is not None else '?'}, commit {culprit or '?'}, "
            f"missed by {orig_tier} review on {overlap_desc}) -> requires >={rec_tier}"
        )

    escalated = TIER_RANK[required_tier] > TIER_RANK[base_tier]
    for chk in recommend_static_checks_for_files(file_list):
        if chk not in static_checks:
            static_checks.append(chk)

    work_type = (
        "triage" if required_tier in {"exempt", "fast"}
        else "security" if required_tier == "human"
        else "review"
    )
    models = _models_for_tier(required_tier, router)
    axes = list(TIER_AXES[required_tier])
    requires_human = required_tier == "human"
    auto_merge_eligible = (
        not draft
        and not fork
        and trusted
        and "one-way-door" not in sig_set
    )

    return Classification(
        pr=number,
        head_sha=head_sha,
        base_tier=base_tier,
        required_tier=required_tier,
        escalated=escalated,
        escalated_from=base_tier if escalated else None,
        escalation_reasons=escalation_reasons,
        reasons=reasons,
        risk_signatures=signatures,
        areas=areas,
        files=file_list,
        axes=axes,
        work_type=work_type,
        recommended_models=models,
        recommended_static_checks=static_checks,
        requires_human_approval=requires_human,
        auto_merge_eligible=auto_merge_eligible,
        matching_incidents=list(dict.fromkeys(matching_incidents)),
    )


def format_attestation_marker(
    *,
    pr: int,
    head_sha: str,
    tier: str,
    status: str = "approved",
    required_tier: str | None = None,
    provider: str | None = None,
    model: str | None = None,
    session_id: str | None = None,
) -> str:
    payload: dict[str, Any] = {
        "pr": int(pr),
        "head_sha": str(head_sha),
        "tier": str(tier),
        "required_tier": str(required_tier or tier),
        "status": str(status).lower(),
    }
    if provider:
        payload["provider"] = provider
    if model:
        payload["model"] = model
    if session_id:
        payload["session_id"] = session_id
    return f"<!-- agent-review: {json.dumps(payload, sort_keys=True)} -->"


def format_review_markdown(
    *,
    classification: Classification,
    status: str = "approved",
    review_tier: str | None = None,
    provider: str | None = None,
    model: str | None = None,
    session_id: str | None = None,
    summary: str = "",
    standards_findings: str = "No blocking standards violations found.",
    spec_findings: str = "Matches issue and source-of-truth specification.",
) -> str:
    effective_tier = review_tier or classification.required_tier
    marker = format_attestation_marker(
        pr=classification.pr,
        head_sha=classification.head_sha,
        tier=effective_tier,
        required_tier=classification.required_tier,
        status=status,
        provider=provider,
        model=model,
        session_id=session_id,
    )
    lines = [
        "> *This was generated by AI during an agent review run.*",
        "",
        f"## Adaptive PR Review — #{classification.pr} (`{classification.head_sha[:7]}`)",
        "",
        f"- **Required tier:** `{classification.required_tier}`"
        + (f" (escalated from `{classification.escalated_from}`)" if classification.escalated else ""),
        f"- **Executed tier:** `{effective_tier}`",
        f"- **Outcome:** `{status}`",
        f"- **Provider / Model:** `{provider or 'none'}` / `{model or 'none'}`",
        f"- **Session:** `{session_id or 'none'}`",
        f"- **Areas:** {', '.join(f'`{a}`' for a in classification.areas) or '`none`'}",
        f"- **Risk signatures:** {', '.join(f'`{s}`' for s in classification.risk_signatures) or '`none`'}",
    ]
    if classification.escalation_reasons:
        lines.extend([
            "",
            "### History Escalation",
            *[f"- {reason}" for reason in classification.escalation_reasons],
        ])
    if classification.recommended_static_checks:
        lines.extend([
            "",
            "### Recommended Verification Checks",
            *[f"- `{chk}`" for chk in classification.recommended_static_checks],
        ])
    if "standards" in classification.axes:
        lines.extend(["", "## Standards", "", standards_findings])
    if "spec" in classification.axes:
        lines.extend(["", "## Spec", "", spec_findings])
    if summary:
        lines.extend(["", "### Summary", "", summary])
    lines.extend(["", marker, ""])
    return "\n".join(lines)


def parse_attestation(body: str) -> dict[str, Any] | None:
    if not body:
        return None
    matches = ATTESTATION_RE.findall(body)
    for raw in reversed(matches):
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if (
            isinstance(data, dict)
            and isinstance(data.get("head_sha"), str)
            and data["head_sha"].strip()
            and data.get("tier") in TIER_RANK
        ):
            return data
    return None


def evaluate_review_attestation(
    *,
    pr_number: int,
    head_sha: str,
    required_tier: str,
    escalated: bool = False,
    escalation_reasons: list[str] | None = None,
    reviews: list[Any] = (),
    comments: list[Any] = (),
    history: list[dict[str, Any]] | None = None,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
    pr_author: str = "",
) -> tuple[bool, str | None]:
    """Check whether exact head_sha has a passing review at >= required_tier.

    Returns ``(True, None)`` when satisfied, or ``(False, blocker_reason)`` when blocked.
    """
    if required_tier not in TIER_RANK:
        raise ValueError(f"unknown required_tier: {required_tier!r}")
    if required_tier == "exempt":
        return True, None

    req_rank = TIER_RANK[required_tier]
    author_key = normalize_bot(pr_author) if pr_author else ""
    best_head_tier: str | None = None
    best_head_human_approved = False
    stale_shas: list[str] = []

    def _record_candidate(
        *,
        sha: str,
        tier: str,
        status: str,
        is_human: bool,
        is_trusted: bool,
    ) -> None:
        nonlocal best_head_tier, best_head_human_approved
        if not is_trusted:
            return
        if status not in {"approved", "APPROVED"}:
            return
        if tier not in TIER_RANK:
            return
        if not sha:
            return
        if sha != head_sha:
            stale_shas.append(sha)
            return
        if is_human:
            best_head_human_approved = True
            best_head_tier = "human"
            return
        if best_head_tier is None or TIER_RANK[tier] > TIER_RANK[best_head_tier]:
            best_head_tier = tier

    # 1. Inspect PR reviews
    for rev in reviews:
        if isinstance(rev, dict):
            state = str(rev.get("state") or "")
            body = str(rev.get("body") or "")
            author = str(rev.get("author") or "")
            bot = bool(rev.get("bot", False))
            assoc = str(rev.get("author_association") or "NONE")
            raw_commit = rev.get("commit")
            if isinstance(raw_commit, dict):
                commit_oid = str(rev.get("commit_oid") or raw_commit.get("oid") or "")
            else:
                commit_oid = str(rev.get("commit_oid") or raw_commit or "")
            explicit_tier = rev.get("tier")
        else:
            state = str(getattr(rev, "state", "") or "")
            body = str(getattr(rev, "body", "") or "")
            author = str(getattr(rev, "author", "") or "")
            bot = bool(getattr(rev, "bot", False))
            assoc = str(getattr(rev, "author_association", "NONE") or "NONE")
            commit_oid = str(getattr(rev, "commit_oid", "") or "")
            explicit_tier = getattr(rev, "tier", None)

        human = is_human_maintainer(author, bot=bot, author_association=assoc, owner=owner)
        trusted = human or is_trusted_actor(author, bot=bot, author_association=assoc, owner=owner, trusted_bots=trusted_bots)
        if author_key and normalize_bot(author) == author_key:
            continue  # the PR author never attests its own change
        attested = parse_attestation(body)

        if attested is not None:
            att_sha = str(attested.get("head_sha") or "")
            # If the review object also binds to a commit OID, both must match head_sha.
            effective_sha = att_sha if (not commit_oid or commit_oid == att_sha) else commit_oid
            _record_candidate(
                sha=effective_sha,
                tier=str(attested.get("tier")),
                status=str(attested.get("status") or ""),
                is_human=human and state == "APPROVED",
                is_trusted=trusted,
            )
        elif state == "APPROVED":
            tier = str(explicit_tier) if explicit_tier in TIER_RANK else ("human" if human else "deep")
            _record_candidate(
                sha=commit_oid,
                tier=tier,
                status="APPROVED",
                is_human=human,
                is_trusted=trusted,
            )

    # 2. Inspect PR comments for structured head-bound agent-review markers
    for comment in comments:
        if isinstance(comment, dict):
            body = str(comment.get("body") or "")
            author_obj = comment.get("author")
            if isinstance(author_obj, dict):
                author = str(author_obj.get("login") or "")
                bot = author_obj.get("__typename") == "Bot" or author.endswith("[bot]")
            else:
                author = str(author_obj or "")
                bot = bool(comment.get("bot", False)) or author.endswith("[bot]")
            assoc = str(comment.get("author_association") or comment.get("authorAssociation") or "NONE")
        else:
            body = str(getattr(comment, "body", "") or "")
            author = str(getattr(comment, "author", "") or "")
            bot = bool(getattr(comment, "bot", False))
            assoc = str(getattr(comment, "author_association", "NONE") or "NONE")

        if author_key and normalize_bot(author) == author_key:
            continue  # the PR author never attests its own change
        attested = parse_attestation(body)
        if attested is None:
            continue
        if attested.get("pr") not in {None, pr_number}:
            continue
        human = is_human_maintainer(author, bot=bot, author_association=assoc, owner=owner)
        trusted = human or is_trusted_actor(author, bot=bot, author_association=assoc, owner=owner, trusted_bots=trusted_bots)
        _record_candidate(
            sha=str(attested.get("head_sha") or ""),
            tier=str(attested.get("tier") or ""),
            status=str(attested.get("status") or ""),
            is_human=False,  # Comments never count as a formal human APPROVED review
            is_trusted=trusted,
        )

    # Recorded history is outcome data for tier learning, never an attestation source:
    # CI writes it and PRs can edit it, so the gate does not trust it here.

    # Evaluate against required_tier
    if required_tier == "human":
        if best_head_human_approved:
            return True, None
        if stale_shas:
            return False, f"stale review (attested for {stale_shas[-1][:7]}, head is {head_sha[:7]}); requires human APPROVED review at {head_sha[:7]}"
        return False, f"requires human APPROVED review at {head_sha[:7]}"

    if best_head_tier is not None and TIER_RANK[best_head_tier] >= req_rank:
        return True, None

    escalation_suffix = " (escalated by incident history)" if escalated else ""
    if best_head_tier is not None:
        return (
            False,
            f"insufficient review tier ({best_head_tier} < required {required_tier}{escalation_suffix} at {head_sha[:7]})",
        )
    if stale_shas:
        return (
            False,
            f"stale review (attested for {stale_shas[-1][:7]}, head is {head_sha[:7]}); "
            f"requires {required_tier} review{escalation_suffix} at {head_sha[:7]}",
        )
    return False, f"missing required {required_tier} review attestation{escalation_suffix} at {head_sha[:7]}"


def parse_pr_json_payload(data: dict[str, Any]) -> dict[str, Any]:
    """Normalize either `gh pr view --json ...` or GraphQL pullRequest node payloads."""
    author_obj = data.get("author") or {}
    if isinstance(author_obj, dict):
        author = str(author_obj.get("login") or "")
        is_bot = bool(author_obj.get("is_bot")) or author_obj.get("__typename") == "Bot" or author.endswith("[bot]")
    else:
        author = str(author_obj or "")
        is_bot = bool(data.get("bot", False)) or author.endswith("[bot]")

    raw_labels = data.get("labels") or []
    if isinstance(raw_labels, dict):
        raw_labels = raw_labels.get("nodes") or []
    labels = [
        str(item.get("name") if isinstance(item, dict) else item)
        for item in raw_labels
        if (item.get("name") if isinstance(item, dict) else item)
    ]

    raw_files = data.get("files") or []
    files_truncated = False
    if isinstance(raw_files, dict):
        files_truncated = bool((raw_files.get("pageInfo") or {}).get("hasNextPage"))
        raw_files = raw_files.get("nodes") or []
    files = [
        str(item.get("path") if isinstance(item, dict) else item)
        for item in raw_files
        if (item.get("path") if isinstance(item, dict) else item)
    ]

    return {
        "number": int(data.get("number") or data.get("pr") or 0),
        "title": str(data.get("title") or ""),
        "body": str(data.get("body") or ""),
        "author": author,
        "bot": is_bot,
        "author_association": str(data.get("authorAssociation") or data.get("author_association") or "NONE"),
        "draft": bool(data.get("isDraft") or data.get("draft")),
        "fork": bool(data.get("isCrossRepository") or data.get("fork")),
        "head_sha": str(data.get("headRefOid") or data.get("head_sha") or data.get("head") or ""),
        "labels": labels,
        "files": files,
        "additions": int(data.get("additions") or 0),
        "deletions": int(data.get("deletions") or 0),
        "changed_files": int(data.get("changedFiles") or data.get("changed_files") or len(files)),
        "files_truncated": bool(data.get("files_truncated") or files_truncated),
    }


def stage_pr_context(
    *,
    pr_meta: dict[str, Any],
    classification: Classification,
    diff_text: str = "",
    state_dir: Path = ROOT / ".agents/state",
    workflow_template: Path = DEFAULT_WORKFLOW,
    stage_workflow_out: Path | None = None,
) -> dict[str, str]:
    """Write pre-staged PR context snapshots (.json and .md) and optionally a staged integrate-pr workflow."""
    state_dir.mkdir(parents=True, exist_ok=True)
    pr_num = classification.pr
    json_snapshot = state_dir / f"pr-{pr_num}.json"
    md_snapshot = state_dir / f"pr-{pr_num}.md"

    snapshot_payload = {
        "pr": pr_num,
        "metadata": pr_meta,
        "classification": classification.to_dict(),
    }
    json_snapshot.write_text(json.dumps(snapshot_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    bounded_diff = diff_text[:12000] if diff_text else "(diff not attached)"
    md_lines = [
        f"# PR #{pr_num}: {pr_meta.get('title', '')}",
        "",
        f"- **Head SHA:** `{classification.head_sha}`",
        f"- **Author:** `{pr_meta.get('author', '')}` (`{pr_meta.get('author_association', 'NONE')}`, bot={pr_meta.get('bot', False)})",
        f"- **Draft / Fork:** draft={pr_meta.get('draft', False)}, fork={pr_meta.get('fork', False)}",
        f"- **Labels:** {', '.join(pr_meta.get('labels', [])) or 'none'}",
        f"- **Diff stats:** +{pr_meta.get('additions', 0)} / -{pr_meta.get('deletions', 0)} across {pr_meta.get('changed_files', len(classification.files))} file(s)",
        f"- **Required review tier:** `{classification.required_tier}` (base `{classification.base_tier}`)",
        f"- **Review axes:** {', '.join(classification.axes) or 'exempt'}",
        f"- **Recommended models:** {', '.join(classification.recommended_models) or 'none'}",
        "",
        "## Classification Reasons",
        *[f"- {r}" for r in classification.reasons],
    ]
    if classification.escalation_reasons:
        md_lines.extend([
            "",
            "## Incident History Escalations",
            *[f"- {r}" for r in classification.escalation_reasons],
        ])
    if classification.recommended_static_checks:
        md_lines.extend([
            "",
            "## Recommended Static Checks",
            *[f"- `{chk}`" for chk in classification.recommended_static_checks],
        ])
    md_lines.extend([
        "",
        "## Changed Files",
        *([f"- `{f}`" for f in classification.files] or ["- (none)"]),
        "",
        "## PR Description (untrusted reporter text)",
        "",
        str(pr_meta.get("body") or "(empty)"),
        "",
        "## Bounded Diff Preview (untrusted code diff)",
        "",
        "```diff",
        bounded_diff,
        "```",
        "",
    ])
    md_snapshot.write_text("\n".join(md_lines), encoding="utf-8")

    rel_json = _rel_path(json_snapshot)
    rel_md = _rel_path(md_snapshot)
    outputs = {"pr_json": rel_json, "pr_md": rel_md}

    if stage_workflow_out is not None:
        workflow = json.loads(workflow_template.read_text(encoding="utf-8"))
        ctx_files = list(workflow.get("context", {}).get("files", []))
        for candidate in (rel_md, rel_json):
            if candidate not in ctx_files and (ROOT / candidate).is_file():
                ctx_files.append(candidate)
        workflow.setdefault("context", {})["files"] = ctx_files
        workflow.setdefault("references", {})["prs"] = [f"#{pr_num}"]

        target_wf_tier = WORKFLOW_TIER_MAP.get(classification.required_tier, "deep")
        for step in workflow.get("steps", []):
            if step.get("id") == "verify-gate":
                step["tier"] = target_wf_tier
            elif step.get("id") == "assess-readiness":
                step["tier"] = "fast" if target_wf_tier == "fast" else "fast"
        stage_workflow_out.parent.mkdir(parents=True, exist_ok=True)
        stage_workflow_out.write_text(json.dumps(workflow, indent=2) + "\n", encoding="utf-8")
        outputs["workflow"] = _rel_path(stage_workflow_out)

    return outputs


def _rel_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT.resolve()))
    except ValueError:
        return str(path)


def _git(repo_root: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(repo_root), *args],
        cwd=repo_root,
        env=isolated_git_env(),
        capture_output=True,
        text=True,
        check=check,
    )


def _commit_files(repo_root: Path, rev: str) -> list[str]:
    out = _git(repo_root, "show", "--pretty=format:", "--name-only", "-m", "--first-parent", rev, check=False).stdout
    return sorted({line.strip() for line in out.splitlines() if line.strip()})


def _commit_info(repo_root: Path, rev: str) -> dict[str, Any]:
    fmt = "%H%x1f%P%x1f%an%x1f%aI%x1f%s%x1f%b"
    out = _git(repo_root, "show", "-s", f"--format={fmt}", rev).stdout
    parts = out.split("\x1f")
    sha = parts[0].strip() if len(parts) > 0 else rev
    parents = parts[1].strip().split() if len(parts) > 1 and parts[1].strip() else []
    author = parts[2].strip() if len(parts) > 2 else ""
    committed_at = parts[3].strip() if len(parts) > 3 else ""
    subject = parts[4].strip() if len(parts) > 4 else ""
    body = parts[5].strip() if len(parts) > 5 else ""
    full_msg = f"{subject}\n{body}"

    prs: list[int] = []
    for match in PR_NUMBER_RE.finditer(full_msg):
        num_str = next((g for g in match.groups() if g), None)
        if num_str:
            num = int(num_str)
            if num not in prs:
                prs.append(num)
    sessions = list(dict.fromkeys(SESSION_TRAILER_RE.findall(full_msg)))
    files = _commit_files(repo_root, sha)
    return {
        "commit": sha,
        "parents": parents,
        "is_merge": len(parents) > 1,
        "author": author,
        "committed_at": committed_at,
        "subject": subject,
        "prs": prs,
        "session_ids": sessions,
        "files": files,
        "areas": infer_areas(files),
    }


def investigate(
    *,
    repo_root: Path = ROOT,
    rev_range: str | None = None,
    commit: str | None = None,
    paths: list[str] | None = None,
    pr_filter: int | None = None,
    since: str | None = None,
    until: str | None = None,
    max_count: int = 30,
    history_path: Path = DEFAULT_HISTORY,
    sessions_path: Path = DEFAULT_SESSIONS,
    ledger_path: Path = DEFAULT_LEDGER,
) -> dict[str, Any]:
    """Correlate git commits/merges with review history, agent sessions, and ledger events."""
    history = load_history(history_path) if history_path.exists() else []
    sessions = load_log(sessions_path, "sessions")
    ledger = load_log(ledger_path, "ledger")

    log_args = ["log", f"--max-count={max_count}", "--format=%H"]
    if since:
        log_args.append(f"--since={since}")
    if until:
        log_args.append(f"--until={until}")
    if commit and not rev_range:
        log_args.extend(["-n", "1", commit])
    elif rev_range:
        log_args.append(rev_range)
    if paths:
        log_args.extend(["--", *paths])

    proc = _git(repo_root, *log_args, check=False)
    shas = [line.strip() for line in proc.stdout.splitlines() if line.strip()]

    reviews_by_pr: dict[int, list[dict[str, Any]]] = {}
    reviews_by_sha: dict[str, list[dict[str, Any]]] = {}
    incidents: list[dict[str, Any]] = []
    for rec in history:
        if rec.get("type") == "review":
            pr_num = rec.get("pr")
            if isinstance(pr_num, int):
                reviews_by_pr.setdefault(pr_num, []).append(rec)
            r_sha = str(rec.get("head_sha") or "")
            if r_sha:
                reviews_by_sha.setdefault(r_sha, []).append(rec)
        elif rec.get("type") == "incident":
            incidents.append(rec)

    filter_paths = [_norm_path(p) for p in (paths or []) if _norm_path(p)]

    def _overlaps(file_list: list[str]) -> list[str]:
        if not filter_paths:
            return file_list
        matched = []
        for f in file_list:
            norm = _norm_path(f)
            if any(norm == fp or norm.startswith(fp.rstrip("/") + "/") for fp in filter_paths):
                matched.append(f)
        return matched

    commit_reports: list[dict[str, Any]] = []
    merged_prs: dict[int, dict[str, Any]] = {}

    for sha in shas:
        info = _commit_info(repo_root, sha)
        overlap = _overlaps(info["files"])
        if filter_paths and not overlap:
            continue

        # Map sessions from index.jsonl by commit SHA prefix or PR reference
        matched_sessions: list[dict[str, Any]] = []
        for sess in sessions:
            sess_commits = [str(c) for c in sess.get("commits", [])]
            sess_prs = [str(p) for p in sess.get("prs", [])]
            sha_hit = any(sha.startswith(c) or c.startswith(sha[:7]) for c in sess_commits if c)
            pr_hit = any(f"#{p}" in sess_prs for p in info["prs"])
            id_hit = sess.get("session_id") in info["session_ids"]
            if sha_hit or pr_hit or id_hit:
                matched_sessions.append({
                    "session_id": sess.get("session_id"),
                    "provider": sess.get("provider"),
                    "harness": sess.get("harness"),
                    "prs": sess_prs,
                    "summary": sess.get("summary"),
                })
                for p_ref in sess_prs:
                    if p_ref.startswith("#") and p_ref[1:].isdigit():
                        p_int = int(p_ref[1:])
                        if p_int not in info["prs"]:
                            info["prs"].append(p_int)

        # Also check if commit SHA matches a review's head_sha
        matched_reviews: list[dict[str, Any]] = list(reviews_by_sha.get(sha, []))
        for r_sha, r_list in reviews_by_sha.items():
            if r_sha != sha and (sha.startswith(r_sha) or r_sha.startswith(sha[:7])):
                for r in r_list:
                    if r not in matched_reviews:
                        matched_reviews.append(r)
        for r in list(matched_reviews):
            r_pr = r.get("pr")
            if isinstance(r_pr, int) and r_pr not in info["prs"]:
                info["prs"].append(r_pr)
        for p_num in info["prs"]:
            for r in reviews_by_pr.get(p_num, []):
                if r not in matched_reviews:
                    matched_reviews.append(r)

        if pr_filter is not None and pr_filter not in info["prs"]:
            continue

        # Match ledger events mentioning the commit or PR
        matched_ledger: list[dict[str, Any]] = []
        for entry in ledger:
            text = json.dumps(entry)
            if sha[:7] in text or any(f"#{p}" in text or f"PR {p}" in text for p in info["prs"]):
                matched_ledger.append(entry)

        info["overlapping_files"] = overlap
        info["reviews"] = matched_reviews
        info["sessions"] = matched_sessions
        info["ledger_events"] = matched_ledger[:5]
        commit_reports.append(info)

        for p_num in info["prs"]:
            latest_rev = matched_reviews[-1] if matched_reviews else None
            merged_prs[p_num] = {
                "pr": p_num,
                "commit": sha,
                "subject": info["subject"],
                "review_tier": latest_rev.get("review_tier") if latest_rev else None,
                "required_tier": latest_rev.get("required_tier") if latest_rev else None,
                "model": latest_rev.get("model") if latest_rev else None,
                "provider": latest_rev.get("provider") if latest_rev else None,
                "status": latest_rev.get("status") if latest_rev else "unrecorded",
                "session_ids": [s["session_id"] for s in matched_sessions if s.get("session_id")],
                "overlapping_files": overlap,
            }

    # Also include PRs directly from review history when pr_filter is set or no git commits matched
    if pr_filter is not None and pr_filter not in merged_prs and pr_filter in reviews_by_pr:
        revs = reviews_by_pr[pr_filter]
        latest = revs[-1]
        merged_prs[pr_filter] = {
            "pr": pr_filter,
            "commit": latest.get("head_sha"),
            "subject": latest.get("summary", ""),
            "review_tier": latest.get("review_tier"),
            "required_tier": latest.get("required_tier"),
            "model": latest.get("model"),
            "provider": latest.get("provider"),
            "status": latest.get("status"),
            "session_ids": [latest["session_id"]] if latest.get("session_id") else [],
            "overlapping_files": _overlaps(latest.get("files", [])),
        }

    matching_incidents = [
        inc for inc in incidents
        if (not filter_paths or _overlaps(inc.get("files", [])))
        and (pr_filter is None or inc.get("pr") == pr_filter)
    ]

    return {
        "range": rev_range or commit or "HEAD",
        "filter_paths": filter_paths,
        "pr_filter": pr_filter,
        "commits": commit_reports,
        "merged_prs": [merged_prs[k] for k in sorted(merged_prs)],
        "incidents": matching_incidents,
    }


def _same_commit(a: str, b: str) -> bool:
    """True when two SHAs (full or abbreviated, at least 7 chars) name the same commit."""
    a, b = (a or "").strip(), (b or "").strip()
    if len(a) < 7 or len(b) < 7:
        return False
    return a.startswith(b) or b.startswith(a)


@contextlib.contextmanager
def _temp_worktree(repo_root: Path, rev: str):
    """Detached throwaway worktree so bisect never touches the caller's checkout."""
    tmp = Path(tempfile.mkdtemp(prefix="pr-review-bisect-"))
    path = tmp / "wt"
    _git(repo_root, "worktree", "add", "--detach", str(path), rev)
    try:
        yield path
    finally:
        _git(repo_root, "worktree", "remove", "--force", str(path), check=False)
        shutil.rmtree(tmp, ignore_errors=True)


def _run_git_bisect(
    repo_root: Path,
    good_rev: str,
    bad_rev: str,
    test_cmd: str,
    *,
    first_parent: bool = False,
) -> str:
    """Execute a non-interactive git bisect and return the culprit commit SHA."""
    start_args = ["bisect", "start"]
    if first_parent:
        start_args.append("--first-parent")
    start_args.extend([bad_rev, good_rev])

    # Bisect state lives in a throwaway worktree, never in the caller's checkout.
    with _temp_worktree(repo_root, bad_rev) as work:
        _git(work, *start_args)
        run_proc = _git(work, "bisect", "run", "sh", "-c", test_cmd, check=False)
        combined = (run_proc.stdout or "") + "\n" + (run_proc.stderr or "")
        match = re.search(r"\b([0-9a-f]{40}) is the first '?bad'? commit\b", combined)
        if match:
            return match.group(1)
        # No conclusive "first bad commit" (e.g. exit 125 or a non-monotonic test): fail
        # instead of reporting the starting revision as the culprit.
        raise RuntimeError(f"git bisect did not identify a culprit commit:\n{combined.strip()}")


def bisect_learn(
    *,
    repo_root: Path = ROOT,
    good_rev: str,
    bad_rev: str = "HEAD",
    test_cmd: str,
    bisect_branch: bool = True,
    first_parent: bool = True,
    failure_signature: str = "",
    record: bool = True,
    history_path: Path = DEFAULT_HISTORY,
    sessions_path: Path = DEFAULT_SESSIONS,
    deeper_review_caught: bool | None = None,
) -> dict[str, Any]:
    """Run dual-level git bisect (merge-level then branch-level) and record an escalating incident."""
    good_sha = _git(repo_root, "rev-parse", "--verify", good_rev).stdout.strip()
    bad_sha = _git(repo_root, "rev-parse", "--verify", bad_rev).stdout.strip()

    merge_culprit = _run_git_bisect(
        repo_root, good_sha, bad_sha, test_cmd, first_parent=first_parent,
    )
    merge_info = _commit_info(repo_root, merge_culprit)
    introducing_culprit = merge_culprit
    branch_bisected = False

    if bisect_branch and len(merge_info["parents"]) >= 2:
        parent1, parent2 = merge_info["parents"][0], merge_info["parents"][1]
        base_proc = _git(repo_root, "merge-base", parent1, parent2, check=False)
        branch_good = base_proc.stdout.strip() if base_proc.returncode == 0 and base_proc.stdout.strip() else parent1
        if branch_good != parent2:
            # Verify parent2 fails test_cmd before bisecting the branch; if parent2 passes,
            # the regression was introduced by the merge combination itself.
            with _temp_worktree(repo_root, parent2) as p2_work:
                test_p2 = subprocess.run(
                    ["sh", "-c", test_cmd],
                    cwd=p2_work,
                    env=isolated_git_env(),
                    capture_output=True,
                    text=True,
                )
            if test_p2.returncode != 0:
                introducing_culprit = _run_git_bisect(
                    repo_root, branch_good, parent2, test_cmd, first_parent=False,
                )
                branch_bisected = True

    culprit_info = _commit_info(repo_root, introducing_culprit)
    all_files = sorted(set(merge_info["files"]) | set(culprit_info["files"]))
    all_areas = infer_areas(all_files)
    candidate_prs = list(dict.fromkeys([*merge_info["prs"], *culprit_info["prs"]]))

    history = load_history(history_path) if history_path.exists() else []
    sessions = load_log(sessions_path, "sessions")

    # Map culprit commit to PR via review history or sessions index if not in commit message
    for rec in history:
        if rec.get("type") == "review":
            r_sha = str(rec.get("head_sha") or "")
            if _same_commit(r_sha, introducing_culprit) or _same_commit(r_sha, merge_culprit):
                if isinstance(rec.get("pr"), int) and rec["pr"] not in candidate_prs:
                    candidate_prs.append(rec["pr"])

    for sess in sessions:
        sess_commits = [str(c) for c in sess.get("commits", [])]
        if any(
            _same_commit(c, introducing_culprit) or _same_commit(c, merge_culprit)
            for c in sess_commits
        ):
            for p_ref in sess.get("prs", []):
                if isinstance(p_ref, str) and p_ref.startswith("#") and p_ref[1:].isdigit():
                    p_int = int(p_ref[1:])
                    if p_int not in candidate_prs:
                        candidate_prs.append(p_int)

    culprit_pr = candidate_prs[0] if candidate_prs else None
    original_review: dict[str, Any] | None = None
    for rec in reversed(history):
        if rec.get("type") != "review":
            continue
        if (culprit_pr is not None and rec.get("pr") == culprit_pr) or (
            _same_commit(str(rec.get("head_sha") or ""), introducing_culprit)
            or _same_commit(str(rec.get("head_sha") or ""), merge_culprit)
        ):
            original_review = rec
            break

    original_tier = str(original_review.get("review_tier")) if original_review and original_review.get("review_tier") in TIER_RANK else "fast"
    original_model = original_review.get("model") if original_review else None

    # Unknown until a retrospective deeper review is run; the tier escalation below is a rule, not evidence.
    would_deeper_catch = deeper_review_caught
    if original_tier in {"exempt", "fast", "balanced"}:
        recommended_tier = "deep"
    else:
        recommended_tier = "human"

    risk_signatures = infer_risk_signatures(
        title=culprit_info["subject"],
        files=all_files,
        changed_files=len(all_files),
    )
    static_checks = recommend_static_checks_for_files(all_files, extra_checks=[test_cmd])
    digest = hashlib.sha256(f"{merge_culprit}:{introducing_culprit}:{test_cmd}".encode("utf-8")).hexdigest()[:10]
    incident_id = f"inc-{digest}"
    sig_text = failure_signature or f"Regression reproduced by `{test_cmd}` at {introducing_culprit[:7]}"

    incident_record: dict[str, Any] = {
        "type": "incident",
        "incident_id": incident_id,
        "timestamp": now_iso(),
        "culprit_commit": introducing_culprit,
        "merge_commit": merge_culprit,
        "branch_bisected": branch_bisected,
        "pr": culprit_pr,
        "pr_ref": f"#{culprit_pr}" if culprit_pr is not None else None,
        "original_review_tier": original_tier,
        "original_model": original_model,
        "recommended_tier": recommended_tier,
        "would_deeper_tier_catch": would_deeper_catch,
        "files": all_files,
        "areas": all_areas,
        "risk_signatures": risk_signatures,
        "failure_signature": sig_text,
        "test_cmd": test_cmd,
        "recommended_static_checks": static_checks,
        "summary": (
            f"Bisect isolated culprit {introducing_culprit[:7]} (merge {merge_culprit[:7]}"
            + (f", PR #{culprit_pr}" if culprit_pr is not None else "")
            + f"); originally reviewed at {original_tier} tier -> escalating {', '.join(all_areas) or 'area'} to {recommended_tier}."
        ),
    }

    if record:
        append_history_record(incident_record, history_path)

    return {
        "good_commit": good_sha,
        "bad_commit": bad_sha,
        "merge_commit": merge_culprit,
        "culprit_commit": introducing_culprit,
        "branch_bisected": branch_bisected,
        "pr": culprit_pr,
        "original_review": original_review,
        "original_review_tier": original_tier,
        "recommended_tier": recommended_tier,
        "would_deeper_tier_catch": would_deeper_catch,
        "files": all_files,
        "areas": all_areas,
        "risk_signatures": risk_signatures,
        "recommended_static_checks": static_checks,
        "recorded": record,
        "incident": incident_record,
    }


def extract_verdict(result: dict[str, Any], root: Path) -> str | None:
    """Return the last agent verdict (APPROVE or CHANGES_REQUESTED) found in the run's step artifacts."""
    verdict: str | None = None
    for artifact in result.get("artifacts", []) or []:
        path = Path(str(artifact))
        if not path.is_absolute():
            path = root / path
        if not path.is_file() or "verify-gate" not in path.name:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        found = VERDICT_RE.findall(text)
        if found:
            verdict = found[-1]
    return verdict


def fetch_pr_via_gh(repo: str, pr_number: int) -> dict[str, Any]:
    fields = (
        "number,title,body,isDraft,isCrossRepository,headRefOid,"
        "author,labels,files,additions,deletions,changedFiles,reviewDecision"
    )
    proc = subprocess.run(
        ["gh", "pr", "view", str(pr_number), "--repo", repo, "--json", fields],
        capture_output=True,
        text=True,
        check=True,
    )
    data = json.loads(proc.stdout)
    # gh pr view has no authorAssociation field; the REST API does.
    assoc = subprocess.run(
        ["gh", "api", f"repos/{repo}/pulls/{pr_number}", "--jq", ".author_association"],
        capture_output=True,
        text=True,
        check=True,
    )
    data["authorAssociation"] = assoc.stdout.strip()
    return data


def cmd_classify(args: argparse.Namespace) -> int:
    raw_data: dict[str, Any] = {}
    if args.pr_json:
        raw_data = json.loads(Path(args.pr_json).read_text(encoding="utf-8"))
    elif args.repo and args.pr:
        raw_data = fetch_pr_via_gh(args.repo, args.pr)

    meta = parse_pr_json_payload(raw_data) if raw_data else {
        "number": args.pr or 0,
        "title": args.title or "",
        "body": args.body or "",
        "author": args.author or "owner",
        "bot": bool(args.bot),
        "author_association": args.author_association or "OWNER",
        "draft": bool(args.draft),
        "fork": bool(args.fork),
        "head_sha": args.head_sha or "",
        "labels": list(args.label or []),
        "files": list(args.file or []),
        "additions": args.additions or 0,
        "deletions": args.deletions or 0,
        "changed_files": args.changed_files or len(args.file or []),
        "files_truncated": bool(args.files_truncated),
    }
    if args.pr:
        meta["number"] = args.pr
    if args.head_sha:
        meta["head_sha"] = args.head_sha
    if args.file:
        meta["files"] = list(dict.fromkeys([*meta.get("files", []), *args.file]))
        meta["changed_files"] = max(meta.get("changed_files", 0), len(meta["files"]))
    if args.label:
        meta["labels"] = list(dict.fromkeys([*meta.get("labels", []), *args.label]))

    history_path = Path(args.history)
    router = json.loads(DEFAULT_ROUTER.read_text(encoding="utf-8")) if DEFAULT_ROUTER.exists() else None
    trusted_bots = trusted_bot_set(args.trusted_bot)
    classification = classify_pr(
        **meta,
        owner=args.owner or "",
        trusted_bots=trusted_bots,
        history_path=history_path,
        router=router,
    )
    output = classification.to_dict()

    if args.stage_dir or args.stage_workflow:
        diff_text = Path(args.diff_file).read_text(encoding="utf-8", errors="replace") if args.diff_file and Path(args.diff_file).exists() else ""
        state_dir = Path(args.stage_dir) if args.stage_dir else ROOT / ".agents/state"
        wf_out = Path(args.stage_workflow) if args.stage_workflow else None
        output["staged"] = stage_pr_context(
            pr_meta=meta,
            classification=classification,
            diff_text=diff_text,
            state_dir=state_dir,
            stage_workflow_out=wf_out,
        )

    print(json.dumps(output, indent=2, sort_keys=True))
    return 0


def cmd_record_review(args: argparse.Namespace) -> int:
    raw_data = json.loads(Path(args.pr_json).read_text(encoding="utf-8")) if args.pr_json and Path(args.pr_json).exists() else {}
    meta = parse_pr_json_payload(raw_data) if raw_data else {
        "number": args.pr,
        "title": args.title or "",
        "body": "",
        "author": args.author or "owner",
        "bot": bool(args.bot),
        "author_association": "OWNER",
        "draft": False,
        "fork": False,
        "head_sha": args.head_sha,
        "labels": [],
        "files": list(args.file or []),
        "additions": 0,
        "deletions": 0,
        "changed_files": len(args.file or []),
        "files_truncated": False,
    }
    if args.pr:
        meta["number"] = args.pr
    if args.head_sha:
        meta["head_sha"] = args.head_sha
    if args.file:
        meta["files"] = list(dict.fromkeys([*meta.get("files", []), *args.file]))
        meta["changed_files"] = max(meta.get("changed_files", 0), len(meta["files"]))

    history_path = Path(args.history)
    classification = classify_pr(
        **meta,
        owner=args.owner or "",
        history_path=history_path,
    )

    provider = args.provider
    model = args.model
    session_id = args.session_id
    status = args.status

    if args.workflow_result and Path(args.workflow_result).exists():
        wf_res = json.loads(Path(args.workflow_result).read_text(encoding="utf-8"))
        if not provider and wf_res.get("providers"):
            provider = wf_res["providers"][0]
        if not model and wf_res.get("models"):
            model = wf_res["models"][0]
        if not session_id and wf_res.get("session_ids"):
            session_id = wf_res["session_ids"][0]
        if not status:
            wf_status = wf_res.get("status")
            if wf_status == "succeeded":
                # A succeeded run only proves the agent finished; the verdict comes from its output.
                verdict = extract_verdict(wf_res, ROOT)
                status = {"APPROVE": "approved", "CHANGES_REQUESTED": "blocked"}.get(verdict or "", "commented")
            elif wf_status in {"planned", "unavailable"}:
                status = "commented"
            else:
                status = "blocked"

    required_tier = args.required_tier or classification.required_tier
    if args.tier:
        review_tier = args.tier
    elif provider == "deterministic-gate":
        review_tier = "fast"  # no model ran; record the tier that actually reviewed
    else:
        review_tier = (
            "exempt" if required_tier == "exempt"
            else ("deep" if required_tier == "human" and args.bot else required_tier)
        )
    effective_status = (status or "approved").lower()
    if required_tier == "human" and args.bot and effective_status == "approved":
        # A bot review on a human-tier PR is advisory only; human APPROVED review is still required.
        effective_status = "commented"

    record = {
        "type": "review",
        "timestamp": now_iso(),
        "pr": int(meta["number"]),
        "pr_ref": f"#{int(meta['number'])}",
        "head_sha": str(meta["head_sha"]),
        "author": str(args.reviewer or meta.get("author") or "github-actions"),
        "bot": bool(args.bot),
        "required_tier": required_tier,
        "review_tier": review_tier,
        "escalated": classification.escalated,
        "status": effective_status,
        "provider": provider,
        "model": model,
        "session_id": session_id,
        "files": classification.files,
        "areas": classification.areas,
        "risk_signatures": classification.risk_signatures,
        "summary": args.summary or f"Adaptive {review_tier} review ({effective_status}) for PR #{meta['number']} at {str(meta['head_sha'])[:7]}.",
    }
    if not args.no_record:
        append_history_record(record, history_path)

    markdown = format_review_markdown(
        classification=classification,
        status=effective_status,
        review_tier=review_tier,
        provider=provider,
        model=model,
        session_id=session_id,
        summary=record["summary"],
        standards_findings=args.standards_findings or "Checked against repository coding standards and baseline code smells.",
        spec_findings=args.spec_findings or "Checked against linked issue and source-of-truth specifications.",
    )
    if args.output_markdown:
        out_md = Path(args.output_markdown)
        out_md.parent.mkdir(parents=True, exist_ok=True)
        out_md.write_text(markdown, encoding="utf-8")

    print(json.dumps({"record": record, "attestation_marker": parse_attestation(markdown)}, indent=2, sort_keys=True))
    return 0


def cmd_record_incident(args: argparse.Namespace) -> int:
    history_path = Path(args.history)
    history = load_history(history_path) if history_path.exists() else []
    repo_root = Path(args.repo_root)

    files = list(args.file or [])
    if not files and (repo_root / ".git").exists():
        files = _commit_files(repo_root, args.culprit_commit)
    areas = infer_areas(files)

    original_tier = args.original_tier
    original_model = args.original_model
    if not original_tier and args.pr:
        for rec in reversed(history):
            if rec.get("type") == "review" and rec.get("pr") == args.pr:
                original_tier = str(rec.get("review_tier") or "fast")
                original_model = original_model or rec.get("model")
                break
    original_tier = original_tier if original_tier in TIER_RANK else "fast"

    if args.recommended_tier:
        recommended_tier = args.recommended_tier
    elif original_tier in {"exempt", "fast", "balanced"}:
        recommended_tier = "deep"
    else:
        recommended_tier = "human"

    would_deeper_catch = {"yes": True, "no": False}.get(args.deeper_review_caught or "")
    extra_checks = list(args.static_check or [])
    if args.test_cmd and args.test_cmd not in extra_checks:
        extra_checks.insert(0, args.test_cmd)
    static_checks = recommend_static_checks_for_files(files, extra_checks=extra_checks)
    risk_signatures = infer_risk_signatures(files=files, changed_files=len(files))

    digest = hashlib.sha256(f"{args.culprit_commit}:{args.pr}:{args.failure_signature}".encode("utf-8")).hexdigest()[:10]
    incident_id = args.incident_id or f"inc-{digest}"

    record: dict[str, Any] = {
        "type": "incident",
        "incident_id": incident_id,
        "timestamp": now_iso(),
        "culprit_commit": args.culprit_commit,
        "merge_commit": args.merge_commit or args.culprit_commit,
        "branch_bisected": False,
        "pr": args.pr,
        "pr_ref": f"#{args.pr}" if args.pr is not None else None,
        "original_review_tier": original_tier,
        "original_model": original_model,
        "recommended_tier": recommended_tier,
        "would_deeper_tier_catch": would_deeper_catch,
        "files": files,
        "areas": areas,
        "risk_signatures": risk_signatures,
        "failure_signature": args.failure_signature or f"Post-merge incident from {args.culprit_commit[:7]}",
        "test_cmd": args.test_cmd,
        "recommended_static_checks": static_checks,
        "summary": args.summary or (
            f"Incident {incident_id} on {', '.join(areas) or 'repo'} from commit {args.culprit_commit[:7]}"
            + (f" (PR #{args.pr})" if args.pr is not None else "")
            + f"; escalates future reviews from {original_tier} to {recommended_tier}."
        ),
    }
    append_history_record(record, history_path)
    print(json.dumps(record, indent=2, sort_keys=True))
    return 0


def cmd_investigate(args: argparse.Namespace) -> int:
    report = investigate(
        repo_root=Path(args.repo_root),
        rev_range=args.range,
        commit=args.commit,
        paths=args.path,
        pr_filter=args.pr,
        since=args.since,
        until=args.until,
        max_count=args.max_count,
        history_path=Path(args.history),
        sessions_path=Path(args.sessions),
        ledger_path=Path(args.ledger),
    )
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


def cmd_bisect_learn(args: argparse.Namespace) -> int:
    report = bisect_learn(
        repo_root=Path(args.repo_root),
        good_rev=args.good,
        bad_rev=args.bad,
        test_cmd=args.test_cmd,
        bisect_branch=args.bisect_branch,
        first_parent=not args.no_first_parent,
        failure_signature=args.failure_signature or "",
        record=not args.no_record,
        history_path=Path(args.history),
        sessions_path=Path(args.sessions),
        deeper_review_caught={"yes": True, "no": False}.get(args.deeper_review_caught or ""),
    )
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    classify_p = sub.add_parser("classify", help="Classify PR review tier with history-driven escalation")
    classify_p.add_argument("--pr", type=int, default=0)
    classify_p.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    classify_p.add_argument("--pr-json", help="Path to PR metadata JSON file")
    classify_p.add_argument("--diff-file", help="Optional path to PR diff file for context staging")
    classify_p.add_argument("--title", default="")
    classify_p.add_argument("--body", default="")
    classify_p.add_argument("--author", default="owner")
    classify_p.add_argument("--bot", action="store_true")
    classify_p.add_argument("--author-association", default="OWNER")
    classify_p.add_argument("--head-sha", default="")
    classify_p.add_argument("--file", action="append", default=[], help="Changed file path (repeatable)")
    classify_p.add_argument("--label", action="append", default=[], help="PR label (repeatable)")
    classify_p.add_argument("--additions", type=int, default=0)
    classify_p.add_argument("--deletions", type=int, default=0)
    classify_p.add_argument("--changed-files", type=int, default=0)
    classify_p.add_argument("--files-truncated", action="store_true")
    classify_p.add_argument("--draft", action="store_true")
    classify_p.add_argument("--fork", action="store_true")
    classify_p.add_argument("--owner", default="")
    classify_p.add_argument("--trusted-bot", action="append", default=[])
    classify_p.add_argument("--history", default=str(DEFAULT_HISTORY))
    classify_p.add_argument("--stage-dir", help="Directory to write pre-staged pr-<N>.json and pr-<N>.md")
    classify_p.add_argument("--stage-workflow", help="Path to write staged integrate-pr workflow JSON")

    rec_rev_p = sub.add_parser("record-review", help="Record a head-bound review decision and output attestation")
    rec_rev_p.add_argument("--pr", type=int, required=True)
    rec_rev_p.add_argument("--head-sha", required=True)
    rec_rev_p.add_argument("--tier", choices=list(TIER_ORDER))
    rec_rev_p.add_argument("--required-tier", choices=list(TIER_ORDER))
    rec_rev_p.add_argument("--status", choices=["approved", "commented", "changes_requested", "blocked", "skipped"])
    rec_rev_p.add_argument("--provider")
    rec_rev_p.add_argument("--model")
    rec_rev_p.add_argument("--session-id")
    rec_rev_p.add_argument("--author", default="")
    rec_rev_p.add_argument("--reviewer", default="")
    rec_rev_p.add_argument("--bot", action="store_true")
    rec_rev_p.add_argument("--title", default="")
    rec_rev_p.add_argument("--file", action="append", default=[])
    rec_rev_p.add_argument("--pr-json", help="Optional PR metadata JSON file")
    rec_rev_p.add_argument("--workflow-result", help="Optional agentctl workflow result.json file")
    rec_rev_p.add_argument("--summary", default="")
    rec_rev_p.add_argument("--standards-findings", default="")
    rec_rev_p.add_argument("--spec-findings", default="")
    rec_rev_p.add_argument("--output-markdown", help="Write formatted PR review markdown with attestation marker")
    rec_rev_p.add_argument("--no-record", action="store_true", help="Do not append to history.jsonl")
    rec_rev_p.add_argument("--owner", default="")
    rec_rev_p.add_argument("--history", default=str(DEFAULT_HISTORY))

    inv_p = sub.add_parser("investigate", help="Investigate merged PRs, review tiers, sessions, and incidents")
    inv_p.add_argument("--range", help="Git revision range (e.g. HEAD~10..HEAD)")
    inv_p.add_argument("--commit", help="Specific commit or ref to inspect")
    inv_p.add_argument("--path", action="append", default=[], help="Filter by file or directory path (repeatable)")
    inv_p.add_argument("--pr", type=int, help="Filter by PR number")
    inv_p.add_argument("--since", help="Git log --since timestamp/date")
    inv_p.add_argument("--until", help="Git log --until timestamp/date")
    inv_p.add_argument("--max-count", type=int, default=30)
    inv_p.add_argument("--repo-root", default=str(ROOT))
    inv_p.add_argument("--history", default=str(DEFAULT_HISTORY))
    inv_p.add_argument("--sessions", default=str(DEFAULT_SESSIONS))
    inv_p.add_argument("--ledger", default=str(DEFAULT_LEDGER))

    bisect_p = sub.add_parser("bisect-learn", help="Run dual-level git bisect and record an escalating incident")
    bisect_p.add_argument("--good", required=True, help="Known good commit/ref")
    bisect_p.add_argument("--bad", default="HEAD", help="Known bad commit/ref (default HEAD)")
    bisect_p.add_argument("--test-cmd", required=True, help="Non-interactive command exiting 0 on good, non-zero on bad")
    bisect_p.add_argument("--bisect-branch", action="store_true", default=True, help="Bisect within culprit merge commit's branch parents")
    bisect_p.add_argument("--no-bisect-branch", dest="bisect_branch", action="store_false")
    bisect_p.add_argument("--no-first-parent", action="store_true", help="Disable --first-parent on the initial bisect pass")
    bisect_p.add_argument("--failure-signature", default="", help="Short description of the regression symptom")
    bisect_p.add_argument("--no-record", action="store_true", help="Do not append the learned incident to history.jsonl")
    bisect_p.add_argument("--deeper-review-caught", choices=["yes", "no"], help="Evidence from a retrospective deeper review; omitted means unknown")
    bisect_p.add_argument("--repo-root", default=str(ROOT))
    bisect_p.add_argument("--history", default=str(DEFAULT_HISTORY))
    bisect_p.add_argument("--sessions", default=str(DEFAULT_SESSIONS))

    inc_p = sub.add_parser("record-incident", help="Record a post-merge regression incident directly")
    inc_p.add_argument("--deeper-review-caught", choices=["yes", "no"], help="Evidence from a retrospective deeper review; omitted means unknown")
    inc_p.add_argument("--culprit-commit", required=True)
    inc_p.add_argument("--merge-commit")
    inc_p.add_argument("--pr", type=int)
    inc_p.add_argument("--original-tier", choices=list(TIER_ORDER))
    inc_p.add_argument("--original-model")
    inc_p.add_argument("--recommended-tier", choices=list(TIER_ORDER))
    inc_p.add_argument("--file", action="append", default=[])
    inc_p.add_argument("--failure-signature", default="")
    inc_p.add_argument("--test-cmd")
    inc_p.add_argument("--static-check", action="append", default=[])
    inc_p.add_argument("--incident-id")
    inc_p.add_argument("--summary", default="")
    inc_p.add_argument("--repo-root", default=str(ROOT))
    inc_p.add_argument("--history", default=str(DEFAULT_HISTORY))

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "classify":
        return cmd_classify(args)
    if args.command == "record-review":
        return cmd_record_review(args)
    if args.command == "investigate":
        return cmd_investigate(args)
    if args.command == "bisect-learn":
        return cmd_bisect_learn(args)
    if args.command == "record-incident":
        return cmd_record_incident(args)
    raise ValueError(f"unsupported command: {args.command}")


if __name__ == "__main__":
    sys.exit(main())
