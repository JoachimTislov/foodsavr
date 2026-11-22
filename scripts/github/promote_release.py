#!/usr/bin/env python3
"""Promote release channels by fast-forward only once source CI is green.

Channel chain (ADR 0007):
  develop -> nightly (daily)
  nightly -> beta    (weekly, Mondays)
  beta    -> stable -> release (biweekly, 1st & 15th)

Dry run by default; ``--apply`` pushes each verified source commit to
``refs/heads/<target>`` using ``GH_TOKEN`` (never creating merge commits and
never force-pushing).
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from checks import QUEUE_CHECK, queue_check_state, rollup_state  # noqa: E402

CHANNELS: dict[str, str] = {
    "nightly": "develop",
    "beta": "nightly",
    "stable": "beta",
    "release": "stable",
}

SCHEDULE_PROMOTIONS: dict[str, list[tuple[str, str]]] = {
    # Daily nightly cut: develop -> nightly
    "0 4 * * *": [("develop", "nightly")],
    # Weekly beta cut (Mondays): nightly -> beta
    "0 5 * * 1": [("nightly", "beta")],
    # Biweekly stable + production release cut (1st & 15th): beta -> stable -> release
    "0 6 1,15 * *": [("beta", "stable"), ("stable", "release")],
}

COMMIT_ROLLUP_QUERY = """
query($owner: String!, $name: String!, $sha: GitObjectID!) {
  repository(owner: $owner, name: $name) {
    object(oid: $sha) {
      ... on Commit {
        statusCheckRollup {
          contexts(first: 100) {
            nodes {
              __typename
              ... on CheckRun { name status conclusion checkSuite { workflowRun { workflow { name } } } }
              ... on StatusContext { context state }
            }
          }
        }
      }
    }
  }
}
"""


@dataclass(frozen=True)
class Decision:
    action: str  # "promote" | "noop" | "pending" | "blocked"
    detail: str


def resolve_steps(
    *,
    schedule: str | None = None,
    target_branch: str | None = None,
    source_branch: str | None = None,
) -> list[tuple[str, str]]:
    """Resolve ordered (source_branch, target_branch) promotion steps."""
    if schedule:
        steps = SCHEDULE_PROMOTIONS.get(schedule.strip())
        if not steps:
            raise ValueError(f"Unsupported schedule cron: {schedule!r}")
        return list(steps)

    target = target_branch or "release"
    if target not in CHANNELS:
        raise ValueError(f"Unsupported target channel: {target!r} (expected one of {sorted(CHANNELS)})")
    source = CHANNELS[target] if not source_branch or source_branch == "default" else source_branch
    if source == target:
        raise ValueError(f"Source and target branch cannot be identical: {source!r}")
    return [(source, target)]


def decide_promotion(
    source_sha: str,
    target_sha: str,
    ancestor: bool,
    contexts: list[dict[str, Any]],
    *,
    source_branch: str = "nightly",
    target_branch: str = "beta",
) -> Decision:
    """Pure promotion gate decision for a candidate source SHA.

    Checks do not re-run on pushes to ``develop`` (PRs into ``develop`` are
    ruleset-gated, and pushing to a release branch runs the release-branch CI
    suite). Therefore ``develop -> <release branch>`` allows fast-forward when
    no checks have failed or are pending on ``source_sha``, while promotions
    between release branches (``nightly -> beta -> stable -> release``) require
    a green rollup and completed ``Detect changed areas`` on ``source_sha``.
    """
    if source_sha == target_sha:
        return Decision("noop", f"{target_branch} is already at {target_sha[:7]}")
    if not ancestor:
        return Decision(
            "blocked",
            f"{target_branch} ({target_sha[:7]}) is not an ancestor of {source_branch} ({source_sha[:7]}); "
            "refusing non-fast-forward",
        )

    rollup = rollup_state(contexts)
    if rollup == "FAILURE":
        return Decision("blocked", f"checks failed on {source_sha[:7]}")
    if rollup == "PENDING":
        return Decision("pending", f"checks still running on {source_sha[:7]}")

    if source_branch != "develop":
        if rollup is None:
            return Decision("pending", f"checks missing on {source_sha[:7]}")
        queue_ok, queue_running = queue_check_state(contexts)
        if queue_running:
            return Decision("pending", f"{QUEUE_CHECK} is still running on {source_sha[:7]}")
        if not queue_ok:
            return Decision("pending", f"waiting for {QUEUE_CHECK} on {source_sha[:7]}")

    return Decision(
        "promote",
        f"fast-forward {target_branch} {target_sha[:7]} -> {source_sha[:7]} (from {source_branch})",
    )


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"git {args[0]} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def is_ancestor(ancestor: str, descendant: str) -> bool:
    result = subprocess.run(["git", "merge-base", "--is-ancestor", ancestor, descendant])
    return result.returncode == 0


def fetch_commit_contexts(repo: str, sha: str) -> list[dict[str, Any]]:
    owner, name = repo.split("/", 1)
    result = subprocess.run(
        [
            "gh",
            "api",
            "graphql",
            "-f",
            f"query={COMMIT_ROLLUP_QUERY}",
            "-F",
            f"owner={owner}",
            "-F",
            f"name={name}",
            "-F",
            f"sha={sha}",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"gh api graphql failed: {result.stderr.strip()}")
    data = json.loads(result.stdout)["data"]["repository"]["object"] or {}
    return ((data.get("statusCheckRollup") or {}).get("contexts") or {}).get("nodes", [])


def fast_forward_branch(repo: str, source_sha: str, target_branch: str, token: str) -> None:
    basic = base64.b64encode(f"x-access-token:{token}".encode("utf-8")).decode("ascii")
    env = {
        **os.environ,
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_CONFIG_COUNT": "1",
        "GIT_CONFIG_KEY_0": "http.https://github.com/.extraheader",
        "GIT_CONFIG_VALUE_0": f"AUTHORIZATION: basic {basic}",
    }
    result = subprocess.run(
        ["git", "push", f"https://github.com/{repo}.git", f"{source_sha}:refs/heads/{target_branch}"],
        capture_output=True,
        text=True,
        env=env,
    )
    if result.returncode != 0:
        raise RuntimeError(f"git push fast-forward to {target_branch} failed: {result.stderr.strip()}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--schedule", default=None, help="GitHub Actions schedule cron expression")
    parser.add_argument("--target-branch", default=None, choices=sorted(CHANNELS))
    parser.add_argument("--source-branch", default=None)
    parser.add_argument("--remote", default="origin")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--strict-pending", action="store_true", help="Exit non-zero if checks are still pending")
    args = parser.parse_args(argv)
    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")

    try:
        steps = resolve_steps(
            schedule=args.schedule,
            target_branch=args.target_branch,
            source_branch=args.source_branch,
        )
    except ValueError as exc:
        parser.error(str(exc))

    token = os.environ.get("GH_TOKEN", "")
    if args.apply and not token:
        print("GH_TOKEN (MERGE_GATE_TOKEN) is required with --apply", file=sys.stderr)
        return 1

    effective_shas: dict[str, str] = {}
    context_cache: dict[str, list[dict[str, Any]]] = {}
    decisions: list[Decision] = []
    sections: list[str] = []

    for source_branch, target_branch in steps:
        source_sha = effective_shas.get(source_branch) or git("rev-parse", f"{args.remote}/{source_branch}")
        target_sha = effective_shas.get(target_branch) or git("rev-parse", f"{args.remote}/{target_branch}")
        ancestor = is_ancestor(target_sha, source_sha)
        if source_sha == target_sha or not ancestor:
            contexts: list[dict[str, Any]] = []
        else:
            if source_sha not in context_cache:
                context_cache[source_sha] = fetch_commit_contexts(args.repo, source_sha)
            contexts = context_cache[source_sha]

        decision = decide_promotion(
            source_sha,
            target_sha,
            ancestor,
            contexts,
            source_branch=source_branch,
            target_branch=target_branch,
        )
        decisions.append(decision)

        section = (
            f"## Promote {source_branch} -> {target_branch}\n\n"
            f"- **Status:** `{decision.action}`\n"
            f"- **Detail:** {decision.detail}\n"
        )
        if decision.action == "promote" and args.apply:
            fast_forward_branch(args.repo, source_sha, target_branch, token)
            effective_shas[target_branch] = source_sha
            section += f"- **Result:** fast-forwarded `{target_branch}` to `{source_sha}`\n"
        elif decision.action == "promote":
            effective_shas[target_branch] = source_sha
            section += "- **Result:** dry run (no push)\n"
        sections.append(section)

    summary = "\n".join(sections)
    print(summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as handle:
            handle.write(summary)

    if any(d.action == "blocked" for d in decisions):
        return 1
    if args.strict_pending and any(d.action == "pending" for d in decisions):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
