#!/usr/bin/env python3
"""Post the `Validation result` commit status for validation.yml.

A commit status (not a check run) is used because GitHub counts a skipped
required check run as passing, while a status that is never posted stays
pending and blocks the merge.

Phases:
  hold   PR without `merge/auto`: pending, nothing was validated.
  start  A run that validates: pending while it executes.
  final  Aggregate the needed jobs into success or failure.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

CONTEXT = "Validation result"
AUTO_LABEL = "merge/auto"
HOLD_DESCRIPTION = "Add merge/auto to run Validation"
START_DESCRIPTION = "Validation running"
SUCCESS_DESCRIPTION = "Validation passed"
FAILURE_DESCRIPTION = "Validation failed"

# The gate job must succeed; downstream jobs may be skipped by its path decision.
GATE_JOB = "changes"
# Ordering-only dependency; its outcome says nothing about the validation.
IGNORED_JOBS = frozenset({"validation-start"})


def decide_hold(*, action: str, label: str) -> tuple[str, str] | None:
    """Status for a PR event whose labels do not include `merge/auto`."""
    if action == "labeled":
        # A foreign label must never overwrite a real result.
        return None
    return "pending", HOLD_DESCRIPTION


def decide_start() -> tuple[str, str]:
    return "pending", START_DESCRIPTION


def decide_final(results: dict[str, str]) -> tuple[str, str] | None:
    """Aggregate needed-job results; None when the run was cancelled."""
    results = {k: v for k, v in results.items() if k not in IGNORED_JOBS}
    values = set(results.values())
    if "cancelled" in values:
        return None
    if results.get(GATE_JOB) != "success":
        return "failure", FAILURE_DESCRIPTION
    if values - {"success", "skipped"}:
        return "failure", FAILURE_DESCRIPTION
    return "success", SUCCESS_DESCRIPTION


def parse_results(raw: str) -> dict[str, str]:
    """Parse `toJSON(needs)` into {job: result}."""
    needs = json.loads(raw)
    return {name: str(job.get("result", "")) for name, job in needs.items()}


def post_status(repo: str, sha: str, state: str, description: str, url: str) -> None:
    subprocess.run(
        [
            "gh", "api", "-X", "POST", f"repos/{repo}/statuses/{sha}",
            "-f", f"state={state}",
            "-f", f"context={CONTEXT}",
            "-f", f"description={description}",
            "-f", f"target_url={url}",
        ],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["hold", "start", "final"])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    env = os.environ
    if args.phase == "hold":
        decision = decide_hold(
            action=env.get("PR_ACTION", ""), label=env.get("PR_LABEL", "")
        )
    elif args.phase == "start":
        decision = decide_start()
    else:
        decision = decide_final(parse_results(env.get("NEEDS_JSON", "{}")))

    if decision is None:
        print(f"No {CONTEXT} status posted for phase '{args.phase}'.")
        return 0
    state, description = decision

    if env.get("IS_FORK") == "true":
        print(
            f"::notice::Fork pull request: the token is read-only, so the "
            f"{CONTEXT} status ({state}) was not posted."
        )
        return 0

    print(f"{CONTEXT}: {state} - {description}")
    if args.dry_run:
        return 0
    post_status(
        env["GITHUB_REPOSITORY"],
        env["TARGET_SHA"],
        state,
        description,
        env.get("RUN_URL", ""),
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
