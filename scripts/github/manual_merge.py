#!/usr/bin/env python3
"""Manual merge bypass: rebase-merge one PR when everything required is green.

The merge gate (scripts/github/merge_gate.py) also demands a head-bound review
attestation at the adaptive review tier and a `merge/auto` opt-in. This script
is the human's bypass for exactly those two conditions: it merges when the
required checks and the `Validation result` status are green on the verified
head, whatever the review tier says. Anything required that is red, pending or
missing refuses the merge. The merge is bound to the verified head SHA, so a
push after verification makes `gh` refuse instead of merging unseen code.

Runs with the caller's own `gh` login. Dry run unless `--apply`.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from branch_governance import default_branch_required_checks  # noqa: E402
from checks import FAILED, IGNORED_WORKFLOWS, effective_runs, _workflow_name  # noqa: E402

BASE = "develop"
VALIDATION_CONTEXT = "Validation result"
ALWAYS_REQUIRED = default_branch_required_checks()
MERGEABLE_STATES = {"CLEAN", "HAS_HOOKS", "UNSTABLE"}

QUERY = """
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      number state isDraft baseRefName headRefName headRefOid mergeStateStatus isCrossRepository
    }
  }
}
"""

CONTEXTS_QUERY = """
query($owner: String!, $name: String!, $head: GitObjectID!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    object(oid: $head) { ... on Commit {
      statusCheckRollup { contexts(first: 100, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          __typename
          ... on CheckRun { name status conclusion startedAt checkSuite { app { slug } workflowRun { databaseId workflow { name } } } }
          ... on StatusContext { context state description }
        }
      } }
    } }
  }
}
"""


@dataclass(frozen=True)
class PullRequest:
    number: int
    state: str
    draft: bool
    base: str
    branch: str
    head: str
    merge_state: str
    fork: bool
    contexts: list[dict[str, Any]] = field(default_factory=list)


@dataclass(frozen=True)
class Verdict:
    ok: bool
    blockers: list[str]
    notes: list[str]
    head: str
    states: dict[str, str]


def from_node(node: dict[str, Any], contexts: list[dict[str, Any]]) -> PullRequest:
    return PullRequest(
        number=node["number"],
        state=node["state"],
        draft=bool(node.get("isDraft")),
        base=node["baseRefName"],
        branch=node.get("headRefName", ""),
        head=node["headRefOid"],
        merge_state=node.get("mergeStateStatus") or "UNKNOWN",
        fork=bool(node.get("isCrossRepository")),
        contexts=contexts,
    )


def _name(context: dict[str, Any]) -> str:
    return context.get("context") if context.get("__typename") == "StatusContext" else context.get("name", "")


def context_state(context: dict[str, Any]) -> str:
    """success | pending | failure for one check run or status context."""
    if context.get("__typename") == "StatusContext":
        return {"SUCCESS": "success", "PENDING": "pending", "EXPECTED": "pending"}.get(context.get("state"), "failure")
    if context.get("status") != "COMPLETED":
        return "pending"
    if context.get("conclusion") in FAILED:
        return "failure"
    # A skipped required check run counts as passing for GitHub too.
    return "success" if context.get("conclusion") in {"SUCCESS", "SKIPPED", "NEUTRAL"} else "failure"


def required_states(contexts: list[dict[str, Any]], required: list[str]) -> dict[str, str]:
    """State of every required check on the head; a check that never reported is pending."""
    effective = effective_runs(contexts)
    worst = {"failure": 2, "pending": 1, "success": 0}
    states: dict[str, str] = {}
    for name in required:
        found = [
            context_state(c) for c in effective
            if _name(c) == name
            and (name != VALIDATION_CONTEXT or c.get("__typename") == "StatusContext")
        ]
        states[name] = max(found, key=worst.__getitem__) if found else "missing"
    return states


def decide(pr: PullRequest, required: list[str]) -> Verdict:
    """Pure readiness decision; the adaptive review tier is deliberately not an input."""
    required = list(dict.fromkeys([*ALWAYS_REQUIRED, *required]))
    blockers: list[str] = []
    notes: list[str] = []
    if pr.state != "OPEN":
        blockers.append(f"PR is {pr.state.lower()}")
    if pr.draft:
        blockers.append("PR is a draft; mark it ready first")
    if pr.base != BASE:
        blockers.append(f"base is {pr.base}, not {BASE}")
    if pr.fork:
        blockers.append("fork PR; merge it from the GitHub UI after reviewing the code")

    states = required_states(pr.contexts, required)
    for name, state in states.items():
        if state == "success":
            continue
        if state == "failure":
            blockers.append(f"required check failed: {name}")
        elif name == VALIDATION_CONTEXT:
            blockers.append(f"{name} is not green on {pr.head[:7]} (run `make validate REF={pr.branch or '<branch>'}`)")
        else:
            reason = "pending" if state == "pending" else "never reported"
            blockers.append(f"required check {reason}: {name}")

    if pr.merge_state == "DIRTY":
        blockers.append(f"conflicts with {BASE}; rebase the branch")
    elif pr.merge_state == "BEHIND":
        blockers.append(f"branch is behind {BASE}; run `gh pr update-branch --rebase {pr.number}` and re-validate")
    elif pr.merge_state == "UNKNOWN":
        blockers.append("GitHub is still computing mergeability; retry in a minute")
    elif pr.merge_state not in MERGEABLE_STATES and not blockers:
        blockers.append(
            f"merge state {pr.merge_state}: branch rules block it beyond the checks (for example a required "
            "review); this bypass never uses --admin"
        )

    others = sorted(
        {
            _name(c)
            for c in effective_runs(pr.contexts)
            if context_state(c) == "failure" and _name(c) not in required and _workflow_name(c) not in IGNORED_WORKFLOWS
        }
    )
    if others:
        notes.append("not required, failing: " + ", ".join(others))
    notes.append("adaptive review tier and merge/auto opt-in bypassed (human merge)")
    return Verdict(not blockers, blockers, notes, pr.head, states)


def gh(*args: str) -> str:
    result = subprocess.run(["gh", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"gh {args[0]} failed: {result.stderr.strip()}")
    return result.stdout


def repo_name(explicit: str | None) -> str:
    return explicit or gh("repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner").strip()


def fetch_pr(repo: str, number: int) -> PullRequest:
    owner, name = repo.split("/", 1)
    fields = ("-F", f"owner={owner}", "-F", f"name={name}")
    out = gh("api", "graphql", "-f", f"query={QUERY}", *fields, "-F", f"number={number}")
    node = json.loads(out)["data"]["repository"]["pullRequest"]
    if node is None:
        raise RuntimeError(f"PR #{number} not found in {repo}")
    head = node["headRefOid"]
    contexts = []
    args = ("api", "graphql", "-f", f"query={CONTEXTS_QUERY}", *fields, "-f", f"head={head}")
    cursor_args = ()
    while True:
        out = gh(*args, *cursor_args)
        commit = json.loads(out)["data"]["repository"]["object"]
        if commit is None:
            raise RuntimeError(f"head {head} not found in {repo}")
        rollup = commit["statusCheckRollup"]
        if rollup is None:
            if cursor_args:
                raise RuntimeError(f"check contexts changed while reading head {head}; retry")
            break
        page = rollup["contexts"]
        contexts.extend(page["nodes"])
        if not page["pageInfo"]["hasNextPage"]:
            break
        cursor = page["pageInfo"]["endCursor"]
        if not cursor or cursor_args == ("-f", f"cursor={cursor}"):
            raise RuntimeError(f"check context pagination stalled on head {head}; retry")
        cursor_args = ("-f", f"cursor={cursor}")
    return from_node(node, contexts)


def ruleset_required(repo: str) -> list[str]:
    """Required status contexts the base branch rules report; empty when unreadable."""
    try:
        rules = json.loads(gh("api", f"repos/{repo}/rules/branches/{BASE}"))
    except (RuntimeError, ValueError):
        return []
    return [
        check["context"]
        for rule in rules
        if rule.get("type") == "required_status_checks"
        for check in (rule.get("parameters") or {}).get("required_status_checks", [])
        if check.get("context")
    ]


def report(pr: PullRequest, verdict: Verdict) -> str:
    lines = [f"PR #{pr.number} ({pr.branch}) head {pr.head[:7]}, merge state {pr.merge_state}"]
    lines += [f"  {state:<8} {name}" for name, state in verdict.states.items()]
    lines += [f"  blocked: {reason}" for reason in verdict.blockers]
    lines += [f"  note: {note}" for note in verdict.notes]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--pr", type=int, required=True)
    parser.add_argument("--repo", default=None, help="OWNER/NAME (default: the gh default repository)")
    parser.add_argument("--apply", action="store_true", help="merge; without it only the decision is printed")
    args = parser.parse_args(argv)
    try:
        repo = repo_name(args.repo)
        pr = fetch_pr(repo, args.pr)
        verdict = decide(pr, ruleset_required(repo))
        print(report(pr, verdict))
        if not verdict.ok:
            print("Refusing to merge.", file=sys.stderr)
            return 1
        if not args.apply:
            print(f"Dry run: would rebase-merge #{pr.number} at {pr.head[:7]}. Re-run with APPLY=1 to merge.")
            return 0
        gh("pr", "merge", str(pr.number), "--repo", repo, "--rebase", "--match-head-commit", pr.head)
        state = json.loads(gh("pr", "view", str(pr.number), "--repo", repo, "--json", "state,mergeCommit"))
        if state["state"] != "MERGED":
            print(f"#{pr.number} is {state['state']}, not merged.", file=sys.stderr)
            return 1
        print(f"Merged #{pr.number} as {state['mergeCommit']['oid'][:7]}.")
        return 0
    except RuntimeError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
