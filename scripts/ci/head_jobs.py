#!/usr/bin/env python3
"""Print the jobs that already succeeded on a commit in other runs of a workflow.

pull-request.yml label and edit events run on a head that a content event (opened,
synchronize, reopened) usually validated already. They skip a suite only when it is
listed here, so a skipped check run never stands in for one that failed or never ran.

Usage: head_jobs.py --workflow pull-request.yml --sha <head> [--exclude-run <id>]
Prints one job name per line (needs GH_TOKEN and GITHUB_REPOSITORY).
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys


def gh_json(*args: str) -> object:
    out = subprocess.run(["gh", *args], capture_output=True, text=True, check=True).stdout
    return json.loads(out or "null")


def passed_jobs(repo: str, workflow: str, sha: str, exclude_run: str = "") -> list[str]:
    runs = gh_json(
        "run", "list", "--repo", repo, "--workflow", workflow, "--commit", sha,
        "--event", "pull_request", "--status", "completed", "--json", "databaseId",
    ) or []
    names: set[str] = set()
    for run in runs:
        run_id = str(run.get("databaseId", ""))
        if not run_id or run_id == exclude_run:
            continue
        payload = gh_json("api", f"repos/{repo}/actions/runs/{run_id}/jobs?per_page=100") or {}
        names.update(job["name"] for job in payload.get("jobs", []) if job.get("conclusion") == "success")
    return sorted(names)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workflow", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--exclude-run", default="")
    args = parser.parse_args(argv)
    try:
        names = passed_jobs(os.environ["GITHUB_REPOSITORY"], args.workflow, args.sha, args.exclude_run)
    except (subprocess.CalledProcessError, ValueError) as error:
        # Fail open toward running the suites: an empty list reuses nothing.
        print(f"head_jobs: cannot list runs ({error}); reusing nothing", file=sys.stderr)
        return 0
    for name in names:
        print(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
