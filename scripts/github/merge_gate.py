#!/usr/bin/env python3
"""Merge gate: integrate opted-in, revertable PRs into develop, one at a time.

Level-triggered: every run reads the whole open-PR queue and takes the next
safe step (ADR 0006, ADR 0007). Dry run by default; ``--apply`` mutates.
"""

from __future__ import annotations

import argparse
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

LABEL = "merge/auto"
LABEL_COLOR = "0e8a16"
LABEL_DESCRIPTION = "Finalized two-way-door PR; the merge gate integrates it"
BASE = "develop"
DEPENDABOT = "dependabot"
ACTIVE = {"queued", "in_progress", "waiting", "requested", "pending"}
REBASE_COMMAND = "@dependabot rebase"
REFUSAL = re.compile(r"can't rebase|cannot rebase|edited by someone other than Dependabot", re.IGNORECASE)
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
        reviewDecision headRefOid
        author { __typename login }
        labels(first: 50) { nodes { name } }
        reviewThreads(first: 100) { nodes { isResolved isOutdated } }
        commits(last: 1) { nodes { commit { committedDate statusCheckRollup { contexts(first: 100) { nodes {
          __typename
          ... on CheckRun { name status conclusion checkSuite { workflowRun { workflow { name } } } }
          ... on StatusContext { context state }
        } } } } } }
        timelineItems(itemTypes: [LABELED_EVENT, UNLABELED_EVENT], last: 50) {
          nodes {
            __typename
            ... on LabeledEvent { createdAt label { name } }
            ... on UnlabeledEvent { label { name } }
          }
        }
        comments(last: 20) { nodes { body createdAt author { login } } }
      }
    }
  }
}
"""


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
    labels: set[str] = field(default_factory=set)
    body: str = ""
    review_decision: str | None = None
    open_threads: int = 0
    label_removed: bool = False
    labeled_at: datetime | None = None
    queue_ok: bool = False
    queue_running: bool = False
    rebase_requested: datetime | None = None
    rebase_refused: bool = False

    @property
    def dependabot(self) -> bool:
        return self.bot and self.author == DEPENDABOT


@dataclass
class Plan:
    actions: list[tuple[str, PR]]
    report: list[tuple[int, str, str]]


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
    comments = node["comments"]["nodes"]
    requested = [parse_time(c["createdAt"]) for c in comments if c["body"].strip() == REBASE_COMMAND]
    refused = [parse_time(c["createdAt"]) for c in comments
               if (c.get("author") or {}).get("login") == DEPENDABOT and REFUSAL.search(c["body"])]
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
        labels={label["name"] for label in node["labels"]["nodes"]},
        body=node.get("body") or "",
        review_decision=node.get("reviewDecision"),
        open_threads=sum(1 for t in node["reviewThreads"]["nodes"] if not t["isResolved"] and not t["isOutdated"]),
        label_removed=unlabeled,
        labeled_at=max(labeled_times) if labeled_times else None,
        queue_ok=queue_ok,
        queue_running=queue_running,
        rebase_requested=max(requested) if requested else None,
        rebase_refused=bool(refused and requested and max(refused) >= max(requested)),
    )


def blocker(pr: PR) -> str | None:
    """Return why an opted-in PR needs its author, or None."""
    if pr.draft:
        return "draft"
    if pr.fork:
        return "fork PRs are not eligible"
    if ONE_WAY.search(pr.body):
        return "PR body declares a one-way door"
    if pr.merge_state == "DIRTY":
        return f"conflicts with {BASE}"
    if pr.review_decision == "CHANGES_REQUESTED":
        return "changes requested"
    if pr.open_threads:
        return f"{pr.open_threads} unresolved review thread(s)"
    if pr.dependabot and pr.rebase_refused and pr.merge_state == "BEHIND":
        return "Dependabot refused to rebase (branch edited); owner decides on @dependabot recreate"
    if pr.rollup == "FAILURE":
        return "a check failed on the head commit"
    return None


def plan(prs: list[PR], now: datetime) -> Plan:
    """Choose the next safe step for the queue. Pure; see ADR 0006 & ADR 0007."""
    actions: list[tuple[str, PR]] = []
    report: list[tuple[int, str, str]] = []
    queue: list[PR] = []
    for pr in sorted(prs, key=lambda p: p.number):
        if LABEL not in pr.labels:
            if pr.dependabot and not pr.draft and not pr.label_removed and bump_kind(pr.title) in {"patch", "minor"}:
                actions.append(("label", pr))
                report.append((pr.number, "opt-in", f"Dependabot {bump_kind(pr.title)} bump"))
            continue
        reason = blocker(pr)
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
    if ready and validating:
        for pr in validating:
            report.append((pr.number, "in flight", "checks running; merges are held so main does not move"))
        for pr in ready:
            report.append((pr.number, "queued", f"held until #{validating[0].number} finishes checks"))
        return Plan(actions, report)
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
    args = parser.parse_args(argv)
    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")
    if args.apply and not serialize(args.repo):
        print("Superseded by a newer merge-gate run.")
        return 0
    gh = GitHub(args.repo, args.apply)
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
        result = plan(prs, datetime.now(timezone.utc))
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
