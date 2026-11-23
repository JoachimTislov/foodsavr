#!/usr/bin/env python3
"""Promote release channels by fast-forward only once source CI is green.

Topologies (ADR 0007, ADR 0008, configured via ``RELEASE_TOPOLOGY``):
  - ``single``:        ``develop`` only (promotions cleanly no-op).
  - ``two-stage``:     ``develop -> stable`` (biweekly schedule or manual).
  - ``full-channels``: ``develop -> daily -> weekly -> stable``.

Dry run by default; ``--apply`` pushes each verified source commit to
``refs/heads/<target>`` using ``GH_TOKEN`` (never creating merge commits and
never force-pushing). It fetches only the branches the resolved steps need and
requires the target branch to exist. Scheduled runs skip missing branches,
and manual runs report them as errors.
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

TOPOLOGIES = ("single", "two-stage", "full-channels")

CHANNELS: dict[str, str] = {
    "daily": "develop",
    "weekly": "daily",
    "stable": "weekly",
}

TOPOLOGY_CHANNELS: dict[str, dict[str, str]] = {
    "single": {},
    "two-stage": {"stable": "develop"},
    "full-channels": CHANNELS,
}

SCHEDULE_PROMOTIONS: dict[str, list[tuple[str, str]]] = {
    # Daily cut: develop -> daily
    "0 4 * * *": [("develop", "daily")],
    # Weekly cut (Mondays): daily -> weekly
    "0 5 * * 1": [("daily", "weekly")],
    # Stable production cut (1st & 15th): weekly -> stable
    "0 6 1,15 * *": [("weekly", "stable")],
}

TOPOLOGY_SCHEDULE_PROMOTIONS: dict[str, dict[str, list[tuple[str, str]]]] = {
    "single": {cron: [] for cron in SCHEDULE_PROMOTIONS},
    "two-stage": {
        "0 4 * * *": [],
        "0 5 * * 1": [],
        "0 6 1,15 * *": [("develop", "stable")],
    },
    "full-channels": SCHEDULE_PROMOTIONS,
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
              ... on CheckRun { name status conclusion startedAt checkSuite { app { slug } workflowRun { databaseId workflow { name } } } }
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
    action: str  # "promote" | "noop" | "pending" | "blocked" | "missing"
    detail: str


def resolve_steps(
    *,
    schedule: str | None = None,
    target_branch: str | None = None,
    source_branch: str | None = None,
    topology: str = "full-channels",
) -> list[tuple[str, str]]:
    """Resolve ordered (source_branch, target_branch) promotion steps."""
    if topology not in TOPOLOGIES:
        raise ValueError(f"Unsupported topology: {topology!r} (expected one of {list(TOPOLOGIES)})")

    if topology == "single":
        return []

    if schedule:
        steps = TOPOLOGY_SCHEDULE_PROMOTIONS[topology].get(schedule.strip())
        if steps is None:
            raise ValueError(f"Unsupported schedule cron: {schedule!r}")
        return list(steps)

    channels = TOPOLOGY_CHANNELS[topology]
    target = target_branch or "stable"
    if target not in channels:
        raise ValueError(
            f"Unsupported target channel {target!r} for topology {topology!r} "
            f"(expected one of {sorted(channels)})"
        )
    source = channels[target] if not source_branch or source_branch == "default" else source_branch
    if source == target:
        raise ValueError(f"Source and target branch cannot be identical: {source!r}")
    return [(source, target)]


def decide_promotion(
    source_sha: str,
    target_sha: str,
    ancestor: bool,
    contexts: list[dict[str, Any]],
    *,
    source_branch: str = "daily",
    target_branch: str = "weekly",
    topology: str = "full-channels",
    target_ahead: bool = False,
) -> Decision:
    """Pure promotion gate decision for a candidate source SHA.

    The first cut from develop starts release-branch CI. Later cuts and
    direct jumps in the full topology require green Validation on the source.
    """
    if source_sha == target_sha:
        return Decision("noop", f"{target_branch} is already at {target_sha[:7]}")
    if target_ahead:
        return Decision("noop", f"{target_branch} ({target_sha[:7]}) is ahead of {source_branch} ({source_sha[:7]})")
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

    first_cut = source_branch == "develop" and TOPOLOGY_CHANNELS[topology].get(target_branch) == "develop"
    if not first_cut:
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


def remote_branches(remote: str, branches: list[str]) -> set[str]:
    """Return the subset of ``branches`` that exist as heads on ``remote``."""
    if not branches:
        return set()
    output = git("ls-remote", "--heads", remote, *branches)
    found: set[str] = set()
    for line in output.splitlines():
        ref = line.split("\t", 1)[-1]
        if ref.startswith("refs/heads/") and ref[len("refs/heads/") :] in branches:
            found.add(ref[len("refs/heads/") :])
    return found


def fetch_branches(remote: str, branches: list[str]) -> None:
    """Fetch exactly ``branches`` (which must exist on ``remote``) without tags."""
    if branches:
        git("fetch", "--no-tags", remote, *(f"+refs/heads/{b}:refs/remotes/{remote}/{b}" for b in branches))


def missing_detail(branch: str, remote: str) -> str:
    return (
        f"branch '{branch}' does not exist on {remote}; "
        "creating channel branches is an owner action (this workflow never creates branches)"
    )


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
    parser.add_argument(
        "--topology",
        default=os.environ.get("RELEASE_TOPOLOGY") or "full-channels",
        choices=list(TOPOLOGIES),
        help="Release topology (single, two-stage, full-channels)",
    )
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
            topology=args.topology,
        )
    except ValueError as exc:
        parser.error(str(exc))

    if not steps:
        msg = f"No promotion steps for topology '{args.topology}' (clean no-op)."
        print(msg)
        summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary_path:
            with open(summary_path, "a", encoding="utf-8") as handle:
                handle.write(f"## Promote release channels\n\n- **Topology:** `{args.topology}`\n- **Result:** {msg}\n")
        return 0

    token = os.environ.get("GH_TOKEN", "")
    if args.apply and not token:
        print("GH_TOKEN (Release-Gate App token or MERGE_GATE_TOKEN) is required with --apply", file=sys.stderr)
        return 1

    scheduled = bool(args.schedule)
    (source_branch, target_branch), = steps
    label = f"{source_branch} -> {target_branch}"
    needed = [source_branch, target_branch]
    existing = remote_branches(args.remote, needed)
    absent = [b for b in needed if b not in existing]
    if absent:
        decision = Decision("missing", ". ".join(missing_detail(b, args.remote) for b in absent))
    else:
        fetch_branches(args.remote, needed)
        source_sha = git("rev-parse", f"refs/remotes/{args.remote}/{source_branch}")
        target_sha = git("rev-parse", f"refs/remotes/{args.remote}/{target_branch}")
        ancestor = is_ancestor(target_sha, source_sha)
        target_ahead = not ancestor and is_ancestor(source_sha, target_sha)
        contexts = fetch_commit_contexts(args.repo, source_sha) if ancestor and source_sha != target_sha else []
        decision = decide_promotion(
            source_sha, target_sha, ancestor, contexts,
            source_branch=source_branch,
            target_branch=target_branch,
            topology=args.topology,
            target_ahead=target_ahead,
        )

    detail = f"{label}: {decision.action}: {decision.detail}"
    if decision.action == "promote":
        if args.apply:
            fast_forward_branch(args.repo, source_sha, target_branch, token)
        else:
            detail += " (dry run)"
    print(detail)
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as handle:
            handle.write(detail + "\n")

    if decision.action == "missing" and not scheduled:
        print(f"::error::{detail}")
        return 1
    return int(decision.action == "blocked" or (args.strict_pending and decision.action == "pending"))


if __name__ == "__main__":
    raise SystemExit(main())
