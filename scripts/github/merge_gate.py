#!/usr/bin/env python3
"""Merge gate: integrate opted-in, revertable PRs into develop, one at a time.

Level-triggered: every run reads the whole open-PR queue and takes the next
safe step (ADR 0006, ADR 0007). Dry run by default; ``--apply`` mutates.
"""

from __future__ import annotations

import argparse
import base64
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from checks import FAILED, QUEUE_CHECK, queue_check_state, review_check_state, rollup_state  # noqa: E402
try:
    from scripts.github import pr_review
except ImportError:
    try:
        import pr_review  # type: ignore[no-redef]
    except ImportError:
        _spec = importlib.util.spec_from_file_location("pr_review", Path(__file__).with_name("pr_review.py"))
        assert _spec is not None and _spec.loader is not None
        pr_review = importlib.util.module_from_spec(_spec)  # type: ignore[assignment]
        sys.modules["pr_review"] = pr_review
        _spec.loader.exec_module(pr_review)

LABEL = "merge/auto"
PRIORITY_LABEL = "merge/priority"
FREEZE_LABEL = "merge/freeze"
FREEZE_MODES = frozenset({"none", "batch", "all"})
TRAIN_PREFIX = "merge-train/pr-"
DEFAULT_TRAIN_DEPTH = 3
MAX_TRAIN_DEPTH = 5
LABEL_COLOR = "0e8a16"
LABEL_DESCRIPTION = "Finalized two-way-door PR; the merge gate integrates it"
BASE = "develop"
DEPENDABOT = "dependabot"
TRUSTED_ASSOCIATIONS = frozenset({"OWNER", "MEMBER", "COLLABORATOR"})
DEFAULT_TRUSTED_BOTS = frozenset({DEPENDABOT, "github-actions"})
ACTIVE = {"queued", "in_progress", "waiting", "requested", "pending"}
REBASE_COMMAND = "@dependabot rebase"
REFUSAL = re.compile(r"can't rebase|cannot rebase|edited by someone other than Dependabot", re.IGNORECASE)
# Paths whose change invalidates running PR checks (mirrors the workflow scopes).
SCOPE = ("lib/", "packages/", "web/", "assets/", "android/", "test/", "integration_test/", "test_driver/",
         "pubspec.", "analysis_options.yaml", ".github/")
SECURITY_LABEL = "risk/security"
SECURITY_PATHS = (
    "infra/terraform/",
    ".github/workflows/",
    ".agents/policies/",
    ".agents/runners/",
    "firestore.rules",
    "firestore-rules/",
)
STALL_AFTER = timedelta(minutes=60)
QUEUE_START_GRACE = timedelta(minutes=10)
REBASE_WAIT = timedelta(minutes=30)
ONE_WAY = re.compile(r"\*\*Door:\*\*\s*one-way", re.IGNORECASE)
BUMP = re.compile(r"\bfrom v?(\d+)\.(\d+)(?:\.(\d+))?\S* to v?(\d+)\.(\d+)(?:\.(\d+))?", re.IGNORECASE)

FREEZE_ISSUES_QUERY = """
query($owner: String!, $name: String!, $label: String!) {
  repository(owner: $owner, name: $name) {
    issues(states: OPEN, labels: [$label], first: 10) {
      nodes { number title }
    }
  }
}
"""

TRAIN_REFS_QUERY = """
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
    refs(refPrefix: "refs/heads/merge-train/", first: 30) {
      nodes {
        name
        prefix
        target {
          ... on Commit {
            oid
            tree { oid }
            statusCheckRollup {
              contexts(first: 100) {
                nodes {
                  __typename
                  ... on CheckRun { name status conclusion startedAt checkSuite { app { slug } workflowRun { databaseId workflow { name } } } }
                  ... on StatusContext { context state }
                }
              }
            }
          }
        }
      }
    }
  }
}
"""

QUERY = """
query($owner: String!, $name: String!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: OPEN, baseRefName: "develop", first: 30, after: $cursor,
                 orderBy: {field: CREATED_AT, direction: ASC}) {
      pageInfo { hasNextPage endCursor }
      nodes {
        id number title body isDraft isCrossRepository mergeStateStatus
        authorAssociation reviewDecision headRefOid baseRefOid
        additions deletions changedFiles
        author { __typename login }
        labels(first: 50) { nodes { name } }
        files(first: 100) { pageInfo { hasNextPage } nodes { path } }
        reviewThreads(first: 100) { pageInfo { hasNextPage } nodes { isResolved isOutdated } }
        reviews(last: 30) {
          nodes {
            state body submittedAt authorAssociation
            author { login __typename }
            commit { oid }
          }
        }
        commits(last: 1) { nodes { commit { committedDate statusCheckRollup { contexts(first: 100) { nodes {
          __typename
          ... on CheckRun { name status conclusion startedAt checkSuite { app { slug } workflowRun { databaseId workflow { name } } } }
          ... on StatusContext { context state }
        } } } } } }
        timelineItems(itemTypes: [LABELED_EVENT, UNLABELED_EVENT], last: 50) {
          nodes {
            __typename
            ... on LabeledEvent { createdAt label { name } }
            ... on UnlabeledEvent { label { name } }
          }
        }
        comments(last: 50) { nodes { body createdAt authorAssociation author { login __typename } } }
      }
    }
  }
}
"""


@dataclass
class Review:
    state: str
    author: str = ""
    bot: bool = False
    author_association: str = "NONE"
    commit_oid: str = ""
    body: str = ""
    submitted_at: datetime | None = None
    tier: str | None = None


@dataclass
class PR:
    number: int
    node_id: str
    title: str
    head: str
    merge_state: str
    rollup: str | None
    head_time: datetime
    base: str = ""
    draft: bool = False
    fork: bool = False
    author: str = ""
    bot: bool = False
    author_association: str = "NONE"
    labels: set[str] = field(default_factory=set)
    body: str = ""
    review_decision: str | None = None
    open_threads: int = 0
    threads_truncated: bool = False
    label_removed: bool = False
    labeled_at: datetime | None = None
    queue_ok: bool = False
    queue_running: bool = False
    review_running: bool = False
    review_started_at: datetime | None = None
    rebase_requested: datetime | None = None
    rebase_refused: bool = False
    additions: int = 0
    deletions: int = 0
    changed_files: int = 0
    files: list[str] = field(default_factory=list)
    files_truncated: bool = False
    reviews: list[Review | dict[str, Any]] = field(default_factory=list)
    comments: list[dict[str, Any]] = field(default_factory=list)
    patch_id: str | None = None

    @property
    def moves_scope(self) -> bool:
        """True when merging this PR could invalidate another PR's running checks."""
        return self.files_truncated or not self.files or any(f.startswith(SCOPE) or f.endswith(".dart") for f in self.files)

    @property
    def dependabot(self) -> bool:
        return self.bot and normalize_bot(self.author) == DEPENDABOT

    @property
    def priority(self) -> bool:
        return PRIORITY_LABEL in self.labels


@dataclass
class Plan:
    actions: list[tuple[str, PR]]
    report: list[tuple[int, str, str]]


@dataclass
class TrainSlot:
    pr: PR
    branch: str
    push: bool


@dataclass
class TrainPlan:
    slots: list[TrainSlot]
    delete_refs: list[str]


@dataclass
class TrainRefState:
    branch: str
    tree_oid: str = ""
    rollup: str | None = None


def normalize_bot(login: str) -> str:
    cleaned = login.strip().lower()
    return cleaned[:-5] if cleaned.endswith("[bot]") else cleaned


def trusted_bot_set(extra: list[str] | None = None) -> frozenset[str]:
    bots = set(DEFAULT_TRUSTED_BOTS)
    for raw in [os.environ.get("AGENT_APP_SLUG", ""), *os.environ.get("TRUSTED_BOTS", "").split(","), *(extra or [])]:
        normalized = normalize_bot(raw)
        if normalized:
            bots.add(normalized)
    return frozenset(bots)


def is_trusted_author(
    pr: PR,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
) -> bool:
    """Return True only for non-fork PRs opened by trusted maintainers or allowlisted bots."""
    if pr.fork or not pr.author:
        return False
    if pr.bot:
        return normalize_bot(pr.author) in trusted_bots
    if owner and pr.author.lower() == owner.lower():
        return True
    return pr.author_association in TRUSTED_ASSOCIATIONS


def parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def bump_kind(title: str) -> str | None:
    match = BUMP.search(title)
    if not match:
        return None
    old = [int(part or 0) for part in match.groups()[:3]]
    new = [int(part or 0) for part in match.groups()[3:]]
    if new[0] != old[0] or (old[0] == 0 and new[1] != old[1]):
        return "major"
    return "minor" if new[1] != old[1] else "patch"


def from_node(node: dict[str, Any]) -> PR:
    commit = (node["commits"]["nodes"] or [{}])[0].get("commit", {})
    contexts = ((commit.get("statusCheckRollup") or {}).get("contexts") or {}).get("nodes", [])
    rollup = rollup_state(contexts)
    queue_ok, queue_running = queue_check_state(contexts)
    review_running, review_started_at = review_check_state(contexts)
    head_time = parse_time(commit["committedDate"]) if commit.get("committedDate") else datetime.now(timezone.utc)
    timeline = node["timelineItems"]["nodes"]
    labeled_times = [
        parse_time(n["createdAt"])
        for n in timeline
        if n.get("__typename") == "LabeledEvent" and (n.get("label") or {}).get("name") == LABEL and n.get("createdAt")
    ]
    unlabeled = any(
        (n.get("__typename") in {None, "UnlabeledEvent"}) and (n.get("label") or {}).get("name") == LABEL
        for n in timeline
    )
    comments = (node.get("comments") or {}).get("nodes") or []
    requested = [parse_time(c["createdAt"]) for c in comments if (c.get("body") or "").strip() == REBASE_COMMAND]
    refused = [
        parse_time(c["createdAt"])
        for c in comments
        if normalize_bot((c.get("author") or {}).get("login") or "") == DEPENDABOT
        and REFUSAL.search(c.get("body") or "")
    ]
    review_threads = node.get("reviewThreads") or {}
    thread_nodes = review_threads.get("nodes") or []
    threads_truncated = bool((review_threads.get("pageInfo") or {}).get("hasNextPage"))

    files_obj = node.get("files") or {}
    file_nodes = files_obj.get("nodes") or []
    files = [f["path"] for f in file_nodes if isinstance(f, dict) and f.get("path")]
    files_truncated = bool((files_obj.get("pageInfo") or {}).get("hasNextPage"))

    raw_reviews = (node.get("reviews") or {}).get("nodes") or []
    reviews: list[Review | dict[str, Any]] = []
    for r in raw_reviews:
        if not isinstance(r, dict):
            continue
        r_author = r.get("author") or {}
        r_login = r_author.get("login", "") if isinstance(r_author, dict) else str(r_author or "")
        r_bot = (
            (r_author.get("__typename") == "Bot" if isinstance(r_author, dict) else False)
            or r_login.lower().endswith("[bot]")
        )
        r_commit = (r.get("commit") or {}).get("oid") or r.get("commit_oid") or ""
        r_time = parse_time(r["submittedAt"]) if r.get("submittedAt") else None
        reviews.append(
            Review(
                state=str(r.get("state") or ""),
                author=r_login,
                bot=r_bot,
                author_association=str(r.get("authorAssociation") or "NONE"),
                commit_oid=str(r_commit),
                body=str(r.get("body") or ""),
                submitted_at=r_time,
                tier=r.get("tier"),
            )
        )

    return PR(
        number=node["number"],
        node_id=node["id"],
        title=node["title"],
        head=node["headRefOid"],
        base=node.get("baseRefOid") or "",
        merge_state=node["mergeStateStatus"],
        rollup=rollup,
        head_time=head_time,
        draft=node["isDraft"],
        fork=node["isCrossRepository"],
        author=(node.get("author") or {}).get("login", ""),
        bot=(node.get("author") or {}).get("__typename") == "Bot",
        author_association=node.get("authorAssociation") or "NONE",
        labels={label["name"] for label in (node.get("labels") or {}).get("nodes", [])},
        body=node.get("body") or "",
        review_decision=node.get("reviewDecision"),
        open_threads=sum(1 for t in thread_nodes if not t["isResolved"] and not t["isOutdated"]),
        threads_truncated=threads_truncated,
        label_removed=unlabeled,
        labeled_at=max(labeled_times) if labeled_times else None,
        queue_ok=queue_ok,
        queue_running=queue_running,
        review_running=review_running,
        review_started_at=review_started_at,
        rebase_requested=max(requested) if requested else None,
        rebase_refused=bool(refused and requested and max(refused) >= max(requested)),
        additions=int(node.get("additions") or 0),
        deletions=int(node.get("deletions") or 0),
        changed_files=int(node.get("changedFiles") or len(files)),
        files=files,
        files_truncated=files_truncated,
        reviews=reviews,
        comments=list(comments),
    )


def classify_for_gate(
    pr: PR,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
    history: list[dict[str, Any]] | None = None,
) -> pr_review.Classification:
    return pr_review.classify_pr(
        number=pr.number,
        title=pr.title,
        body=pr.body,
        author=pr.author,
        bot=pr.bot,
        author_association=pr.author_association,
        draft=pr.draft,
        fork=pr.fork,
        head_sha=pr.head,
        labels=pr.labels,
        files=pr.files,
        additions=pr.additions,
        deletions=pr.deletions,
        changed_files=pr.changed_files or len(pr.files),
        files_truncated=pr.files_truncated,
        rollup=pr.rollup,
        owner=owner,
        trusted_bots=trusted_bots,
        history=history,
    )


def structural_blocker(
    pr: PR,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
) -> str | None:
    """Return hard non-review blockers for an opted-in PR, or None."""
    if pr.draft:
        return "draft"
    if pr.fork:
        return "fork PRs are not eligible"
    if not is_trusted_author(pr, owner=owner, trusted_bots=trusted_bots):
        role = "bot" if pr.bot else f"association {pr.author_association}"
        return f"author {pr.author or 'unknown'} ({role}) is not trusted for auto-merge"
    if SECURITY_LABEL in pr.labels:
        return f"{SECURITY_LABEL} PRs require human merge"
    if pr.files is not None and any(f == p or f.startswith(p) for f in pr.files for p in SECURITY_PATHS):
        return "touches security-sensitive paths; requires human merge"
    if ONE_WAY.search(pr.body):
        return "PR body declares a one-way door"
    if pr.merge_state == "DIRTY":
        return f"conflicts with {BASE}"
    if pr.review_decision == "CHANGES_REQUESTED":
        return "changes requested"
    if pr.open_threads:
        return f"{pr.open_threads} unresolved review thread(s)"
    if pr.threads_truncated:
        return "review threads truncated (>100); resolve or inspect manually"
    if pr.dependabot and pr.rebase_refused and pr.merge_state == "BEHIND":
        return "Dependabot refused to rebase (branch edited); owner decides on @dependabot recreate"
    if pr.rollup == "FAILURE":
        return "a check failed on the head commit"
    return None


def review_blocker(
    pr: PR,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
    history: list[dict[str, Any]] | None = None,
) -> str | None:
    """Return missing/insufficient review attestation reason, or None."""
    effective_history = history if history is not None else pr_review.load_history()
    classification = classify_for_gate(pr, owner=owner, trusted_bots=trusted_bots, history=effective_history)
    ok, reason = pr_review.evaluate_review_attestation(
        pr_number=pr.number,
        head_sha=pr.head,
        required_tier=classification.required_tier,
        escalated=classification.escalated,
        escalation_reasons=classification.escalation_reasons,
        reviews=pr.reviews,
        comments=pr.comments,
        history=effective_history,
        pr_author=pr.author,
        owner=owner,
        trusted_bots=trusted_bots,
        current_patch_id=pr.patch_id,
    )
    return None if ok else reason


def blocker(
    pr: PR,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
    history: list[dict[str, Any]] | None = None,
) -> str | None:
    """Return why an opted-in PR needs its author or reviewer, or None."""
    hard = structural_blocker(pr, owner=owner, trusted_bots=trusted_bots)
    if hard:
        return hard
    return review_blocker(pr, owner=owner, trusted_bots=trusted_bots, history=history)


def resolve_freeze_mode(
    env_value: str | None = None,
    freeze_issues: list[dict[str, Any]] | tuple[dict[str, Any], ...] = (),
    lookup_error: str | None = None,
) -> tuple[str, str]:
    """Resolve effective integration freeze mode ('none', 'batch', or 'all') and human-readable reason.

    ``MERGE_GATE_FREEZE=all|true`` freezes every PR; ``batch`` freezes normal ``merge/auto`` PRs
    while allowing ``merge/priority`` PRs through. When the variable is unset/none, any open
    issue labeled ``merge/freeze`` activates ``batch`` freeze, and a failed lookup fails closed
    to ``all``. Unknown non-empty values also fail closed to ``all``.
    """
    raw = (env_value or "").strip().lower()
    issue_refs = [f"#{i['number']}" for i in freeze_issues if isinstance(i, dict) and i.get("number")]
    issue_suffix = f" ({', '.join(issue_refs)})" if issue_refs else ""

    if raw in {"all", "true", "1", "yes"}:
        return "all", f"MERGE_GATE_FREEZE={raw}{issue_suffix}"
    if raw == "batch":
        return "batch", f"MERGE_GATE_FREEZE=batch{issue_suffix}"
    if raw in {"", "none", "false", "0", "no"}:
        if lookup_error:
            return "all", f"freeze-issue lookup failed ({lookup_error}); failing closed to all"
        if issue_refs:
            return "batch", f"open {FREEZE_LABEL} issue(s): {', '.join(issue_refs)}"
        return "none", ""
    return "all", f"unknown MERGE_GATE_FREEZE={raw!r}; failing closed to all"


def _queue_rank(pr: PR) -> tuple[int, int]:
    """Order priority PRs before normal PRs, oldest-first within each tier."""
    return (0 if pr.priority else 1, pr.number)


def plan(
    prs: list[PR],
    now: datetime,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
    history: list[dict[str, Any]] | None = None,
    freeze_mode: str = "none",
    freeze_reason: str = "",
) -> Plan:
    """Choose the next safe step for the queue. Pure; see ADR 0006."""
    if freeze_mode not in FREEZE_MODES:
        raise ValueError(f"unknown freeze_mode: {freeze_mode!r}")
    actions: list[tuple[str, PR]] = []
    report: list[tuple[int, str, str]] = []
    queue: list[PR] = []
    review_in_flight: list[PR] = []
    effective_history = history if history is not None else pr_review.load_history()
    for pr in sorted(prs, key=_queue_rank):
        if LABEL not in pr.labels:
            if (
                pr.dependabot
                and not pr.draft
                and not pr.label_removed
                and is_trusted_author(pr, owner=owner, trusted_bots=trusted_bots)
                and bump_kind(pr.title) in {"patch", "minor"}
            ):
                if freeze_mode != "none":
                    detail = f"integration freeze ({freeze_mode}): Dependabot auto opt-in paused"
                    if freeze_reason:
                        detail = f"{detail} ({freeze_reason})"
                    report.append((pr.number, "frozen", detail))
                else:
                    actions.append(("label", pr))
                    report.append((pr.number, "opt-in", f"Dependabot {bump_kind(pr.title)} bump"))
            elif not pr.draft:
                if not is_trusted_author(pr, owner=owner, trusted_bots=trusted_bots):
                    report.append((pr.number, "untrusted", "author is not trusted for auto-merge"))
                elif pr.label_removed:
                    report.append((pr.number, "held", "merge/auto was removed; re-add to integrate"))
                elif pr.dependabot and bump_kind(pr.title) == "major":
                    report.append((pr.number, "awaiting opt-in", "Dependabot major bump; add merge/auto to integrate"))
                else:
                    report.append((pr.number, "awaiting opt-in", "ready for review; add merge/auto to integrate"))
            continue

        if freeze_mode == "all":
            detail = f"integration freeze (all): {freeze_reason}" if freeze_reason else "integration freeze (all)"
            report.append((pr.number, "frozen", detail))
            continue
        if freeze_mode == "batch" and not pr.priority:
            base_detail = f"integration freeze (batch): {freeze_reason}" if freeze_reason else "integration freeze (batch)"
            report.append((pr.number, "frozen", f"{base_detail}; add {PRIORITY_LABEL} to preempt"))
            continue

        hard = structural_blocker(pr, owner=owner, trusted_bots=trusted_bots)
        if hard:
            reasons = [hard]
            # Report all independently actionable safeguards. This prevents a green
            # Validation result from hiding security, thread, or review blockers.
            if pr.open_threads and "unresolved review thread" not in hard:
                reasons.append(f"{pr.open_threads} unresolved review thread(s)")
            if pr.threads_truncated and "review threads truncated" not in hard:
                reasons.append("review threads truncated (>100); resolve or inspect manually")
            rev = review_blocker(pr, owner=owner, trusted_bots=trusted_bots, history=effective_history)
            if rev:
                reasons.append(rev)
            report.append((pr.number, "blocked", "; ".join(reasons)))
            continue
        rev = review_blocker(pr, owner=owner, trusted_bots=trusted_bots, history=effective_history)
        if rev:
            review_activity_at = (
                pr.review_started_at
                if pr.review_started_at is not None
                else (max(pr.head_time, pr.labeled_at) if pr.labeled_at else pr.head_time)
            )
            if pr.review_running and now - review_activity_at < STALL_AFTER:
                review_in_flight.append(pr)
                report.append((pr.number, "in flight", f"Agent review running ({rev})"))
            else:
                report.append((pr.number, "blocked", rev))
            continue
        queue.append(pr)

    # UNSTABLE only reflects non-required checks; the gate's own rollup and queue Validation must be green.
    ready = [
        p for p in queue
        if p.merge_state in {"CLEAN", "HAS_HOOKS", "UNSTABLE"} and p.rollup == "SUCCESS" and p.queue_ok
    ]
    # A merge moves develop and forces other in-scope PRs to restart checks. Hold
    # an in-scope ready PR only behind higher-priority / older up-to-date PRs that
    # are still validating, so priority or older ready PRs are never blocked by newer ones.
    validating = [
        p for p in queue
        if p.merge_state in {"CLEAN", "HAS_HOOKS", "UNSTABLE", "BLOCKED"}
        and p.rollup in {None, "PENDING"} and now - p.head_time < STALL_AFTER
    ]
    # Out-of-scope merges (docs, agent files) leave running checks valid: the
    # rebased head reuses them (scripts/ci/already_tested.sh), so only in-scope PRs wait.
    def _blocking_validating(p: PR) -> list[PR]:
        if not p.moves_scope:
            return []
        return [v for v in validating if _queue_rank(v) < _queue_rank(p)]

    free = [p for p in ready if not _blocking_validating(p)]
    if ready and not free:
        for pr in validating:
            report.append((pr.number, "in flight", "checks running; in-scope merges are held"))
        for pr in ready:
            holder = _blocking_validating(pr)[0]
            report.append((pr.number, "queued", f"held until #{holder.number} finishes checks"))
        return Plan(actions, report)
    ready = free
    if ready:
        pr = ready[0]
        actions.append(("merge", pr))
        report.append((pr.number, "merge", f"all checks green at {pr.head[:7]}"))
        for other in queue:
            if other is not pr:
                report.append((other.number, "queued", "waits for the merge in progress"))
        return Plan(actions, report)

    in_flight: list[PR] = list(review_in_flight)
    behind: list[PR] = []
    for pr in queue:
        activity_at = max(pr.head_time, pr.labeled_at) if pr.labeled_at else pr.head_time
        if pr.merge_state == "BEHIND":
            rebasing = pr.dependabot and pr.rebase_requested and pr.rebase_requested > pr.head_time and now - pr.rebase_requested < REBASE_WAIT
            (in_flight if rebasing else behind).append(pr)
            report.append((pr.number, "in flight" if rebasing else "behind",
                           "Dependabot rebase requested" if rebasing else f"needs update with {BASE}"))
        elif pr.merge_state == "UNKNOWN":
            report.append((pr.number, "unknown", "GitHub is computing mergeability"))
        elif (pr.queue_running or pr.rollup in {None, "PENDING"}) and now - activity_at < STALL_AFTER:
            in_flight.append(pr)
            report.append((pr.number, "in flight", "checks running"))
        elif not pr.queue_ok and now - activity_at < QUEUE_START_GRACE:
            in_flight.append(pr)
            report.append((pr.number, "in flight", "waiting for queue checks to start"))
        elif not pr.queue_ok:
            report.append((pr.number, "blocked", f"queue checks ({QUEUE_CHECK}) did not run on this head"))
        else:
            report.append((pr.number, "blocked", f"merge state {pr.merge_state}, checks {pr.rollup}"))
    if behind and not in_flight:
        actions.append(("update", behind[0]))
    return Plan(actions, report)


def needs_patch_id(pr: PR) -> bool:
    """True when an opted-in PR has an approved attestation carrying patch_id on an older head."""
    if LABEL not in pr.labels or pr.draft or pr.fork:
        return False
    for item in (*pr.reviews, *pr.comments):
        body = item.get("body", "") if isinstance(item, dict) else getattr(item, "body", "")
        att = pr_review.parse_attestation(str(body or ""))
        if not att:
            continue
        if (
            att.get("head_sha") != pr.head
            and att.get("patch_id")
            and str(att.get("status") or "").lower() == "approved"
        ):
            return True
    return False


def resolve_train_depth(raw: str | int | None) -> int:
    """Resolve speculative merge-train depth (0 disables; clamped to MAX_TRAIN_DEPTH)."""
    if raw is None:
        return DEFAULT_TRAIN_DEPTH
    if isinstance(raw, int) and not isinstance(raw, bool):
        return max(0, min(MAX_TRAIN_DEPTH, raw))
    text = str(raw).strip()
    if not text:
        return DEFAULT_TRAIN_DEPTH
    try:
        value = int(text)
    except ValueError:
        return 0
    return max(0, min(MAX_TRAIN_DEPTH, value))


def plan_train(
    prs: list[PR],
    existing_train_refs: list[str] | tuple[str, ...] | set[str],
    depth: int = DEFAULT_TRAIN_DEPTH,
    freeze_mode: str = "none",
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
    history: list[dict[str, Any]] | None = None,
) -> TrainPlan:
    """Plan speculative merge-train refs for queued PRs and stale refs to delete.

    Slot 0 is the head of the queue (validated directly on its PR branch, so
    ``push=False``, though an existing train ref for slot 0 is retained while
    the PR stays open so its rebased PR run can reuse that tree). Slots
    ``1..depth`` are replayed linearly on top of ``develop`` and pushed when
    their combined tree changes.
    """
    if freeze_mode not in FREEZE_MODES:
        raise ValueError(f"unknown freeze_mode: {freeze_mode!r}")
    managed_refs = sorted({ref for ref in existing_train_refs if ref.startswith(TRAIN_PREFIX)})
    effective_depth = resolve_train_depth(depth)
    if effective_depth <= 0 or freeze_mode == "all":
        return TrainPlan(slots=[], delete_refs=managed_refs)

    effective_history = history if history is not None else pr_review.load_history()
    eligible: list[PR] = []
    for pr in sorted(prs, key=_queue_rank):
        if LABEL not in pr.labels:
            continue
        if freeze_mode == "batch" and not pr.priority:
            continue
        if pr.merge_state == "UNKNOWN":
            continue
        if structural_blocker(pr, owner=owner, trusted_bots=trusted_bots):
            continue
        if review_blocker(pr, owner=owner, trusted_bots=trusted_bots, history=effective_history):
            continue
        eligible.append(pr)

    chosen = eligible[: effective_depth + 1]
    slots = [
        TrainSlot(pr=pr, branch=f"{TRAIN_PREFIX}{pr.number}", push=(idx >= 1))
        for idx, pr in enumerate(chosen)
    ]
    keep_refs = {slot.branch for slot in slots}
    delete_refs = [ref for ref in managed_refs if ref not in keep_refs]
    return TrainPlan(slots=slots, delete_refs=delete_refs)


class GitHub:
    def __init__(self, repo: str, apply: bool):
        self.owner, self.name = repo.split("/", 1)
        self.repo = repo
        self.apply = apply

    def run(self, *args: str, stdin: str | None = None) -> str:
        result = subprocess.run(["gh", *args], input=stdin, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"gh {args[0]} failed: {result.stderr.strip()}")
        return result.stdout

    def prs(self) -> list[PR]:
        nodes: list[dict[str, Any]] = []
        cursor: str | None = None
        while True:
            args = ["api", "graphql", "-f", f"query={QUERY}", "-F", f"owner={self.owner}", "-F", f"name={self.name}"]
            if cursor:
                args += ["-F", f"cursor={cursor}"]
            page = json.loads(self.run(*args))["data"]["repository"]["pullRequests"]
            nodes += page["nodes"]
            if not page["pageInfo"]["hasNextPage"]:
                return [from_node(node) for node in nodes]
            cursor = page["pageInfo"]["endCursor"]

    def freeze_issues(self) -> list[dict[str, Any]]:
        data = json.loads(
            self.run(
                "api", "graphql",
                "-f", f"query={FREEZE_ISSUES_QUERY}",
                "-F", f"owner={self.owner}",
                "-F", f"name={self.name}",
                "-F", f"label={FREEZE_LABEL}",
            )
        )
        return list((data["data"]["repository"]["issues"] or {}).get("nodes") or [])

    def safe_freeze_issues(self) -> tuple[list[dict[str, Any]], str | None]:
        """Fetch open freeze issues, returning (issues, error) so lookup failures fail closed."""
        try:
            return self.freeze_issues(), None
        except RuntimeError as error:
            return [], str(error)

    def train_refs(self) -> list[str]:
        """List existing merge-train/pr-* branch names on the repository."""
        try:
            items = json.loads(self.run("api", f"repos/{self.repo}/git/matching-refs/heads/merge-train/"))
        except RuntimeError:
            return []
        if not isinstance(items, list):
            return []
        refs: list[str] = []
        for item in items:
            if not isinstance(item, dict):
                continue
            ref = str(item.get("ref") or "")
            prefix = "refs/heads/"
            if ref.startswith(prefix):
                branch = ref[len(prefix):]
                if branch.startswith(TRAIN_PREFIX):
                    refs.append(branch)
        return sorted(set(refs))

    def train_ref_states(self) -> dict[str, TrainRefState]:
        """Fetch existing merge-train/pr-* refs with their tip tree OID and check rollup."""
        try:
            data = json.loads(
                self.run(
                    "api", "graphql",
                    "-f", f"query={TRAIN_REFS_QUERY}",
                    "-F", f"owner={self.owner}",
                    "-F", f"name={self.name}",
                )
            )
            nodes = ((data["data"]["repository"].get("refs") or {}).get("nodes") or [])
        except (RuntimeError, KeyError, TypeError, json.JSONDecodeError):
            return {ref: TrainRefState(branch=ref) for ref in self.train_refs()}

        states: dict[str, TrainRefState] = {}
        for node in nodes:
            if not isinstance(node, dict):
                continue
            raw_name = str(node.get("name") or "")
            raw_prefix = str(node.get("prefix") or "refs/heads/merge-train/")
            if raw_name.startswith(TRAIN_PREFIX):
                branch = raw_name
            else:
                full_ref = f"{raw_prefix}{raw_name}"
                branch = full_ref[len("refs/heads/"):] if full_ref.startswith("refs/heads/") else raw_name
            if not branch.startswith(TRAIN_PREFIX):
                continue
            target = node.get("target") or {}
            tree_oid = str((target.get("tree") or {}).get("oid") or "")
            contexts = (((target.get("statusCheckRollup") or {}).get("contexts") or {}).get("nodes") or [])
            states[branch] = TrainRefState(
                branch=branch,
                tree_oid=tree_oid,
                rollup=rollup_state(contexts),
            )
        return states

    def sync_train(
        self,
        train_plan: TrainPlan,
        remote_url: str | None = None,
        token: str | None = None,
        failed_train_trees: dict[str, str] | None = None,
    ) -> list[str]:
        """Linearly replay speculative train slots onto develop and sync train refs."""
        push_slots = [slot for slot in train_plan.slots if slot.push]
        if not push_slots and not train_plan.delete_refs:
            return []
        if not self.apply:
            notes = [
                f"train #{slot.pr.number}: would sync {slot.branch} (dry run)"
                + (" [currently failing]" if failed_train_trees and slot.branch in failed_train_trees else "")
                for slot in push_slots
            ]
            notes += [f"train cleanup: would delete {ref} (dry run)" for ref in train_plan.delete_refs]
            return notes

        url = remote_url or f"https://github.com/{self.repo}.git"
        auth_args: list[str] = []
        if url.startswith("https://"):
            effective_token = token if token is not None else os.environ.get("GH_TOKEN", "")
            if effective_token:
                basic = base64.b64encode(f"x-access-token:{effective_token}".encode("utf-8")).decode("ascii")
                auth_args = ["-c", f"http.https://github.com/.extraheader=AUTHORIZATION: basic {basic}"]

        def _git(cwd: Path, *git_args: str, network: bool = False, check: bool = True) -> subprocess.CompletedProcess[str]:
            cmd = ["git", *(auth_args if network else []), *git_args]
            proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
            if check and proc.returncode != 0:
                sub = git_args[0] if git_args else "git"
                raise RuntimeError(f"git {sub} failed: {proc.stderr.strip()}")
            return proc

        notes: list[str] = []
        refs_to_delete: set[str] = set(train_plan.delete_refs)

        with tempfile.TemporaryDirectory(prefix="merge-train-") as tmp:
            work = Path(tmp)
            _git(work, "init", "-q")
            _git(work, "config", "user.name", "merge-gate[bot]")
            _git(work, "config", "user.email", "merge-gate[bot]@users.noreply.github.com")
            _git(work, "remote", "add", "origin", url)

            if push_slots:
                _git(work, "fetch", "--no-tags", "origin", f"refs/heads/{BASE}:refs/remotes/origin/{BASE}", network=True)
                train_tip = _git(work, "rev-parse", f"refs/remotes/origin/{BASE}").stdout.strip()

                existing_trees: dict[str, str] = {}
                for slot in push_slots:
                    fetched = _git(
                        work,
                        "fetch",
                        "--no-tags",
                        "--depth=1",
                        "origin",
                        f"refs/heads/{slot.branch}:refs/remotes/origin/{slot.branch}",
                        network=True,
                        check=False,
                    )
                    if fetched.returncode == 0:
                        tree_proc = _git(work, "rev-parse", f"refs/remotes/origin/{slot.branch}^{{tree}}", check=False)
                        if tree_proc.returncode == 0:
                            existing_trees[slot.branch] = tree_proc.stdout.strip()

                for slot in train_plan.slots:
                    pr_ref = f"refs/remotes/origin/pr-{slot.pr.number}"
                    fetched_pr = _git(
                        work,
                        "fetch",
                        "--no-tags",
                        "origin",
                        f"refs/pull/{slot.pr.number}/head:{pr_ref}",
                        network=True,
                        check=False,
                    )
                    if fetched_pr.returncode != 0:
                        notes.append(f"train #{slot.pr.number}: skipped (could not fetch PR ref)")
                        if slot.branch in existing_trees:
                            refs_to_delete.add(slot.branch)
                        continue
                    fetched_head = _git(work, "rev-parse", pr_ref).stdout.strip()
                    if fetched_head != slot.pr.head:
                        notes.append(f"train #{slot.pr.number}: skipped (head moved from {slot.pr.head[:7]} to {fetched_head[:7]})")
                        continue
                    mb_proc = _git(work, "merge-base", f"refs/remotes/origin/{BASE}", fetched_head, check=False)
                    if mb_proc.returncode != 0:
                        notes.append(f"train #{slot.pr.number}: skipped (no merge-base with {BASE})")
                        if slot.branch in existing_trees:
                            refs_to_delete.add(slot.branch)
                        continue
                    merge_base = mb_proc.stdout.strip()
                    merges_out = _git(work, "rev-list", "--merges", f"{merge_base}..{fetched_head}").stdout.strip()
                    if merges_out:
                        notes.append(f"train #{slot.pr.number}: ejected (contains merge commits)")
                        if slot.branch in existing_trees:
                            refs_to_delete.add(slot.branch)
                        continue
                    _git(work, "checkout", "-q", "--detach", train_tip)
                    if merge_base != fetched_head:
                        cp = _git(work, "cherry-pick", f"{merge_base}..{fetched_head}", check=False)
                        if cp.returncode != 0:
                            _git(work, "cherry-pick", "--abort", check=False)
                            _git(work, "reset", "--hard", "-q", train_tip, check=False)
                            notes.append(f"train #{slot.pr.number}: ejected (rebase conflict on speculative tip)")
                            if slot.branch in existing_trees:
                                refs_to_delete.add(slot.branch)
                            continue
                    new_tip = _git(work, "rev-parse", "HEAD").stdout.strip()
                    new_tree = _git(work, "rev-parse", "HEAD^{tree}").stdout.strip()
                    if slot.push and failed_train_trees and failed_train_trees.get(slot.branch) == new_tree:
                        _git(work, "reset", "--hard", "-q", train_tip, check=False)
                        notes.append(f"train #{slot.pr.number}: ejected ({slot.branch} failed checks at tree {new_tree[:7]})")
                        continue
                    train_tip = new_tip
                    if not slot.push:
                        continue
                    if existing_trees.get(slot.branch) == new_tree:
                        notes.append(f"train #{slot.pr.number}: {slot.branch} unchanged (tree {new_tree[:7]})")
                        continue
                    push_proc = _git(
                        work,
                        "push",
                        "--force",
                        "origin",
                        f"{new_tip}:refs/heads/{slot.branch}",
                        network=True,
                        check=False,
                    )
                    if push_proc.returncode == 0:
                        notes.append(f"train #{slot.pr.number}: pushed {slot.branch} ({new_tip[:7]}, tree {new_tree[:7]})")
                    else:
                        notes.append(f"train #{slot.pr.number}: failed to push {slot.branch}: {push_proc.stderr.strip()}")

            for ref in sorted(refs_to_delete):
                del_proc = _git(work, "push", "origin", f":refs/heads/{ref}", network=True, check=False)
                if del_proc.returncode == 0:
                    notes.append(f"train cleanup: deleted {ref}")
                else:
                    notes.append(f"train cleanup: could not delete {ref}: {del_proc.stderr.strip()}")
        return notes

    def populate_patch_ids(self, prs: list[PR]) -> None:
        """Compute current patch_id for opted-in PRs that may carry over a prior review."""
        for pr in prs:
            if not needs_patch_id(pr):
                continue
            if not pr.base or not pr.head:
                pr.patch_id = None
                continue
            try:
                diff_text = self.run(
                    "api",
                    "-H",
                    "Accept: application/vnd.github.v3.diff",
                    f"repos/{self.repo}/compare/{pr.base}...{pr.head}",
                )
            except RuntimeError:
                pr.patch_id = None
                continue
            pr.patch_id = pr_review.compute_patch_id(diff_text)

    def execute(self, action: str, pr: PR) -> str:
        if not self.apply:
            return "dry run"
        if action == "label":
            if not self._label_exists():
                self.run("api", f"repos/{self.repo}/labels", "-X", "POST", "-f", f"name={LABEL}", "-f", f"color={LABEL_COLOR}", "-f", f"description={LABEL_DESCRIPTION}")
            self.run("api", f"repos/{self.repo}/issues/{pr.number}/labels", "-X", "POST", "-f", f"labels[]={LABEL}")
            return "labeled"
        if action == "merge":
            self.run("pr", "merge", str(pr.number), "--repo", self.repo, "--rebase", "--match-head-commit", pr.head)
            state = json.loads(self.run("pr", "view", str(pr.number), "--repo", self.repo, "--json", "state,mergeCommit"))
            if state["state"] != "MERGED":
                raise RuntimeError(f"#{pr.number} not merged (state {state['state']})")
            return f"merged as {state['mergeCommit']['oid'][:7]}"
        if action == "update" and pr.dependabot:
            self.run("pr", "comment", str(pr.number), "--repo", self.repo, "--body", REBASE_COMMAND)
            return "asked Dependabot to rebase"
        if action == "update":
            mutation = (
                "mutation($id: ID!, $head: GitObjectID!) { updatePullRequestBranch(input: "
                "{pullRequestId: $id, expectedHeadOid: $head, updateMethod: REBASE}) { pullRequest { headRefOid } } }"
            )
            out = json.loads(self.run("api", "graphql", "-f", f"query={mutation}", "-F", f"id={pr.node_id}", "-F", f"head={pr.head}"))
            return f"rebased onto {BASE} as {out['data']['updatePullRequestBranch']['pullRequest']['headRefOid'][:7]}"
        raise ValueError(action)

    def _label_exists(self) -> bool:
        try:
            self.run("api", f"repos/{self.repo}/labels/{LABEL.replace('/', '%2F')}")
            return True
        except RuntimeError:
            return False


def gate_runs(repo: str, token: str) -> list[dict[str, Any]]:
    out = subprocess.run(
        ["gh", "api", f"repos/{repo}/actions/workflows/merge-gate.yml/runs?per_page=50", "--jq", ".workflow_runs"],
        capture_output=True, text=True, check=True, env={**os.environ, "GH_TOKEN": token})
    return json.loads(out.stdout)


def supersession(runs: list[dict[str, Any]], me: int) -> str | None:
    """'exit' when a newer gate run will act, 'wait' while an older one acts, else None.

    Replaces a concurrency group: cancelled queued runs would mark develop's
    checks as failing, and the newest event's run always executes.
    """
    active = [r for r in runs if r["status"] in ACTIVE and r["id"] != me and r["event"] != "pull_request_target"
              and (r.get("actor") or {}).get("login") != "dependabot[bot]"]
    if any(r["id"] > me for r in active):
        return "exit"
    if any(r["id"] < me for r in active):
        return "wait"
    return None


def serialize(repo: str) -> bool:
    """Return False when a newer run supersedes this one."""
    me, token = os.environ.get("GITHUB_RUN_ID"), os.environ.get("RUNS_TOKEN")
    if not me or not token:
        return True
    deadline = time.monotonic() + 8 * 60
    while time.monotonic() < deadline:
        state = supersession(gate_runs(repo, token), int(me))
        if state != "wait":
            return state != "exit"
        time.sleep(10)
    return True


def summarize(
    rows: list[tuple[int, str, str]],
    done: list[str],
    freeze_mode: str = "none",
    freeze_reason: str = "",
    train_notes: list[str] | None = None,
) -> str:
    lines = ["## Merge gate", ""]
    if freeze_mode != "none":
        reason_text = f" ({freeze_reason})" if freeze_reason else ""
        lines += [f"**Integration freeze active:** `{freeze_mode}`{reason_text}", ""]
    lines += ["| PR | State | Detail |", "|---|---|---|"]
    lines += [f"| #{n} | {state} | {detail} |" for n, state, detail in rows] or ["| — | idle | no opted-in PRs |"]
    if done:
        lines += ["", *[f"- {line}" for line in done]]
    if train_notes:
        lines += ["", "### Speculative merge train", "", *[f"- {line}" for line in train_notes]]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--max-merges", type=int, default=5)
    parser.add_argument("--freeze", default=os.environ.get("MERGE_GATE_FREEZE", ""),
                        help="Freeze mode override: none, batch, or all (defaults to MERGE_GATE_FREEZE env)")
    parser.add_argument("--train-depth", default=os.environ.get("MERGE_TRAIN_DEPTH", ""),
                        help="Speculative merge-train depth (0 disables; defaults to MERGE_TRAIN_DEPTH env or 3)")
    parser.add_argument("--trusted-bot", action="append", default=[],
                        help="Additional bot login or App slug trusted for auto-merge")
    args = parser.parse_args(argv)
    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")
    if args.apply and not serialize(args.repo):
        print("Superseded by a newer merge-gate run.")
        return 0
    gh = GitHub(args.repo, args.apply)
    trusted_bots = trusted_bot_set(args.trusted_bot)
    done: list[str] = []
    rows: list[tuple[int, str, str]] = []
    prs: list[PR] = []
    freeze_mode = "none"
    freeze_reason = ""
    freeze_lookup_error: str | None = None
    merges = 0
    status = 0
    mutated_last = False
    for _ in range(args.max_merges * 2 + 2):
        prs = gh.prs()
        for _retry in range(3):
            if not any(p.merge_state == "UNKNOWN" and LABEL in p.labels for p in prs):
                break
            time.sleep(10)
            prs = gh.prs()
        freeze_issues, freeze_lookup_error = gh.safe_freeze_issues()
        freeze_mode, freeze_reason = resolve_freeze_mode(
            args.freeze,
            freeze_issues,
            lookup_error=freeze_lookup_error,
        )
        gh.populate_patch_ids(prs)
        result = plan(
            prs,
            datetime.now(timezone.utc),
            owner=gh.owner,
            trusted_bots=trusted_bots,
            freeze_mode=freeze_mode,
            freeze_reason=freeze_reason,
        )
        rows = result.report
        merged = False
        mutated_last = False
        for action, pr in result.actions:
            if args.apply and action in {"merge", "update", "label"}:
                live_issues, live_error = gh.safe_freeze_issues()
                live_mode, live_reason = resolve_freeze_mode(
                    args.freeze,
                    live_issues,
                    lookup_error=live_error,
                )
                blocked_by_freeze = (
                    live_mode == "all"
                    or (live_mode == "batch" and (action == "label" or not pr.priority))
                )
                if blocked_by_freeze:
                    freeze_mode, freeze_reason = live_mode, live_reason
                    freeze_lookup_error = live_error
                    done.append(f"#{pr.number}: {action} skipped — integration freeze ({live_mode}: {live_reason})")
                    print(done[-1], flush=True)
                    break
            try:
                outcome = gh.execute(action, pr)
            except RuntimeError as error:
                outcome, status = f"failed: {error}", 1
            done.append(f"#{pr.number}: {action} — {outcome}")
            print(done[-1], flush=True)
            if args.apply and not outcome.startswith("failed"):
                mutated_last = True
            merged = merged or (action == "merge" and not outcome.startswith("failed"))
        merges += merged
        if status or not (merged and args.apply) or merges >= args.max_merges:
            break

    train_notes: list[str] = []
    if status == 0:
        if mutated_last and args.apply:
            prs = gh.prs()
            freeze_issues, freeze_lookup_error = gh.safe_freeze_issues()
            freeze_mode, freeze_reason = resolve_freeze_mode(
                args.freeze,
                freeze_issues,
                lookup_error=freeze_lookup_error,
            )
            gh.populate_patch_ids(prs)
        if freeze_lookup_error:
            train_notes = [f"train sync skipped: freeze-issue lookup failed ({freeze_lookup_error})"]
        else:
            train_depth = resolve_train_depth(args.train_depth)
            train_states = gh.train_ref_states()
            failed_train_trees = {
                branch: state.tree_oid
                for branch, state in train_states.items()
                if state.rollup == "FAILURE" and state.tree_oid
            }
            train_plan = plan_train(
                prs,
                list(train_states),
                depth=train_depth,
                freeze_mode=freeze_mode,
                owner=gh.owner,
                trusted_bots=trusted_bots,
            )
            try:
                train_notes = gh.sync_train(train_plan, failed_train_trees=failed_train_trees)
            except RuntimeError as error:
                train_notes = [f"train sync warning: {error}"]
        for note in train_notes:
            print(note, flush=True)

    text = summarize(
        rows,
        done,
        freeze_mode=freeze_mode,
        freeze_reason=freeze_reason,
        train_notes=train_notes,
    )
    print(text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as handle:
            handle.write(text)
    return status


if __name__ == "__main__":
    sys.exit(main())
