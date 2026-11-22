#!/usr/bin/env python3
"""Promote develop -> main by fast-forward only once develop CI is green.

Dry run by default; ``--apply`` pushes ``develop``'s verified commit to
``refs/heads/main`` using ``GH_TOKEN`` (never creating merge commits and never
force-pushing). See ADR 0007.
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


def decide_promotion(
    develop_sha: str,
    main_sha: str,
    is_ancestor: bool,
    contexts: list[dict[str, Any]],
) -> Decision:
    """Pure promotion gate decision for a candidate develop SHA."""
    if develop_sha == main_sha:
        return Decision("noop", f"main is already at {main_sha[:7]}")
    if not is_ancestor:
        return Decision(
            "blocked",
            f"main ({main_sha[:7]}) is not an ancestor of develop ({develop_sha[:7]}); refusing non-fast-forward",
        )

    rollup = rollup_state(contexts)
    if rollup == "FAILURE":
        return Decision("blocked", f"checks failed on {develop_sha[:7]}")
    if rollup in {None, "PENDING"}:
        return Decision("pending", f"checks still running or missing on {develop_sha[:7]}")

    queue_ok, queue_running = queue_check_state(contexts)
    if queue_running:
        return Decision("pending", f"{QUEUE_CHECK} is still running on {develop_sha[:7]}")
    if not queue_ok:
        return Decision("pending", f"waiting for {QUEUE_CHECK} on {develop_sha[:7]}")

    return Decision("promote", f"fast-forward main {main_sha[:7]} -> {develop_sha[:7]}")


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


def fast_forward_main(repo: str, develop_sha: str, token: str) -> None:
    basic = base64.b64encode(f"x-access-token:{token}".encode("utf-8")).decode("ascii")
    env = {
        **os.environ,
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_CONFIG_COUNT": "1",
        "GIT_CONFIG_KEY_0": "http.https://github.com/.extraheader",
        "GIT_CONFIG_VALUE_0": f"AUTHORIZATION: basic {basic}",
    }
    result = subprocess.run(
        ["git", "push", f"https://github.com/{repo}.git", f"{develop_sha}:refs/heads/main"],
        capture_output=True,
        text=True,
        env=env,
    )
    if result.returncode != 0:
        raise RuntimeError(f"git push fast-forward failed: {result.stderr.strip()}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--develop-ref", default="origin/develop")
    parser.add_argument("--main-ref", default="origin/main")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--strict-pending", action="store_true", help="Exit non-zero if checks are still pending")
    args = parser.parse_args(argv)
    if not args.repo:
        parser.error("--repo or GITHUB_REPOSITORY is required")

    develop_sha = git("rev-parse", args.develop_ref)
    main_sha = git("rev-parse", args.main_ref)
    ancestor = is_ancestor(main_sha, develop_sha)
    contexts = [] if develop_sha == main_sha or not ancestor else fetch_commit_contexts(args.repo, develop_sha)
    decision = decide_promotion(develop_sha, main_sha, ancestor, contexts)

    summary = f"## Promote develop -> main\n\n- **Status:** `{decision.action}`\n- **Detail:** {decision.detail}\n"
    if decision.action == "promote" and args.apply:
        token = os.environ.get("GH_TOKEN", "")
        if not token:
            print("GH_TOKEN (MERGE_GATE_TOKEN) is required with --apply", file=sys.stderr)
            return 1
        fast_forward_main(args.repo, develop_sha, token)
        summary += f"- **Result:** fast-forwarded `main` to `{develop_sha}`\n"
    elif decision.action == "promote":
        summary += "- **Result:** dry run (no push)\n"

    print(summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as handle:
            handle.write(summary)

    if decision.action == "blocked":
        return 1
    if decision.action == "pending" and args.strict_pending:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
