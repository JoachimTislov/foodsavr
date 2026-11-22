#!/usr/bin/env python3
"""Merge gate: integrate opted-in, revertable PRs into develop, one at a time.

Level-triggered: every run reads the whole open-PR queue and takes the next
safe step (ADR 0006, ADR 0007). Dry run by default; ``--apply`` mutates.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from checks import FAILED, IGNORED_WORKFLOWS, QUEUE_CHECK, queue_check_state, rollup_state  # noqa: E402
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

QUERY = """
query($owner: String!, $name: String!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: OPEN, baseRefName: "develop", first: 30, after: $cursor,
                 orderBy: {field: CREATED_AT, direction: ASC}) {
      pageInfo { hasNextPage endCursor }
      nodes {
        id number title body isDraft isCrossRepository mergeStateStatus
        authorAssociation reviewDecision headRefOid
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
          ... on CheckRun { name status conclusion checkSuite { app { slug } workflowRun { workflow { name } } } }
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
    rebase_requested: datetime | None = None
    rebase_refused: bool = False
    additions: int = 0
    deletions: int = 0
    changed_files: int = 0
    files: list[str] = field(default_factory=list)
    files_truncated: bool = False
    reviews: list[Review | dict[str, Any]] = field(default_factory=list)
    comments: list[dict[str, Any]] = field(default_factory=list)

    @property
    def moves_scope(self) -> bool:
        """True when merging this PR could invalidate another PR's running checks."""
        return self.files_truncated or not self.files or any(f.startswith(SCOPE) or f.endswith(".dart") for f in self.files)

    @property
    def dependabot(self) -> bool:
        return self.bot and normalize_bot(self.author) == DEPENDABOT


@dataclass
class Plan:
    actions: list[tuple[str, PR]]
    report: list[tuple[int, str, str]]


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


def blocker(
    pr: PR,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
    history: list[dict[str, Any]] | None = None,
) -> str | None:
    """Return why an opted-in PR needs its author or reviewer, or None."""
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

    effective_history = history if history is not None else pr_review.load_history()
    classification = classify_for_gate(pr, owner=owner, trusted_bots=trusted_bots, history=effective_history)
    ok, review_blocker = pr_review.evaluate_review_attestation(
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
    )
    if not ok:
        return review_blocker
    return None


def plan(
    prs: list[PR],
    now: datetime,
    owner: str = "",
    trusted_bots: frozenset[str] = DEFAULT_TRUSTED_BOTS,
    history: list[dict[str, Any]] | None = None,
) -> Plan:
    """Choose the next safe step for the queue. Pure; see ADR 0006."""
    actions: list[tuple[str, PR]] = []
    report: list[tuple[int, str, str]] = []
    queue: list[PR] = []
    effective_history = history if history is not None else pr_review.load_history()
    for pr in sorted(prs, key=lambda p: p.number):
        if LABEL not in pr.labels:
            if (
                pr.dependabot
                and not pr.draft
                and not pr.label_removed
                and is_trusted_author(pr, owner=owner, trusted_bots=trusted_bots)
                and bump_kind(pr.title) in {"patch", "minor"}
            ):
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
        reason = blocker(pr, owner=owner, trusted_bots=trusted_bots, history=effective_history)
        if reason:
            report.append((pr.number, "blocked", reason))
            continue
        queue.append(pr)

    # UNSTABLE only reflects non-required checks; the gate's own rollup and queue Validation must be green.
    ready = [
        p for p in queue
        if p.merge_state in {"CLEAN", "HAS_HOOKS", "UNSTABLE"} and p.rollup == "SUCCESS" and p.queue_ok
    ]
    # A merge moves main and forces every other PR to restart its checks. Hold
    # ready PRs while an up-to-date PR is still validating, so slow checks (for
    # example a Dependabot PR's smoke tests) finish instead of being reset.
    validating = [
        p for p in queue
        if p.merge_state in {"CLEAN", "HAS_HOOKS", "UNSTABLE", "BLOCKED"}
        and p.rollup in {None, "PENDING"} and now - p.head_time < STALL_AFTER
    ]
    # Out-of-scope merges (docs, agent files) leave running checks valid: the
    # rebased head reuses them (scripts/ci/already_tested.sh), so only in-scope PRs wait.
    free = [p for p in ready if not (validating and p.moves_scope)]
    if ready and not free:
        for pr in validating:
            report.append((pr.number, "in flight", "checks running; in-scope merges are held"))
        for pr in ready:
            report.append((pr.number, "queued", f"held until #{validating[0].number} finishes checks"))
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

    in_flight: list[PR] = []
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


def summarize(rows: list[tuple[int, str, str]], done: list[str]) -> str:
    lines = ["## Merge gate", "", "| PR | State | Detail |", "|---|---|---|"]
    lines += [f"| #{n} | {state} | {detail} |" for n, state, detail in rows] or ["| — | idle | no opted-in PRs |"]
    if done:
        lines += ["", *[f"- {line}" for line in done]]
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--max-merges", type=int, default=5)
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
    merges = 0
    status = 0
    for _ in range(args.max_merges * 2 + 2):
        prs = gh.prs()
        for _retry in range(3):
            if not any(p.merge_state == "UNKNOWN" and LABEL in p.labels for p in prs):
                break
            time.sleep(10)
            prs = gh.prs()
        result = plan(prs, datetime.now(timezone.utc), owner=gh.owner, trusted_bots=trusted_bots)
        rows = result.report
        merged = False
        for action, pr in result.actions:
            try:
                outcome = gh.execute(action, pr)
            except RuntimeError as error:
                outcome, status = f"failed: {error}", 1
            done.append(f"#{pr.number}: {action} — {outcome}")
            print(done[-1], flush=True)
            merged = merged or (action == "merge" and not outcome.startswith("failed"))
        merges += merged
        if status or not (merged and args.apply) or merges >= args.max_merges:
            break
    text = summarize(rows, done)
    print(text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as handle:
            handle.write(text)
    return status


if __name__ == "__main__":
    sys.exit(main())
