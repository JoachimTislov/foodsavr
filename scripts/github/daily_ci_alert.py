#!/usr/bin/env python3
"""Open, update, or auto-close a deduplicated triage issue for daily CI regressions."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Protocol

ROOT = Path(__file__).resolve().parents[2]

ALERT_MARKER = "<!-- daily-ci-failure -->"
ISSUE_TITLE = "bug(ci): daily CI regression"
ISSUE_LABELS: tuple[str, ...] = ("type/bug", "area/ci")

TRACKED_JOBS: tuple[tuple[str, str], ...] = (
    ("gate", "Decide whether to run CI"),
    ("check", "Check & Test"),
    ("changes", "Detect changed areas"),
    ("web-validation", "Web validation"),
    ("validation-result", "Validation status (result)"),
)


class GhClient(Protocol):
    def list_open_alert_issues(self) -> list[dict[str, Any]]: ...
    def create_issue(self, title: str, body: str, labels: list[str]) -> dict[str, Any]: ...
    def comment_issue(self, number: int, body: str) -> None: ...
    def close_issue(self, number: int, reason: str = "completed") -> None: ...


class SubprocessGhClient:
    """GitHub CLI wrapper for daily CI triage issue reconciliation."""

    def __init__(self, repo: str | None = None, cwd: Path = ROOT) -> None:
        self.repo = repo or os.environ.get("GITHUB_REPOSITORY") or ""
        self.cwd = cwd

    def _repo_args(self) -> list[str]:
        return ["--repo", self.repo] if self.repo else []

    def _run(self, args: list[str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["gh", *args],
            cwd=self.cwd,
            capture_output=True,
            text=True,
            check=True,
        )

    def list_open_alert_issues(self) -> list[dict[str, Any]]:
        res = self._run(
            [
                "issue",
                "list",
                *self._repo_args(),
                "--state",
                "open",
                "--limit",
                "100",
                "--json",
                "number,title,body,url,labels",
            ]
        )
        issues = json.loads(res.stdout or "[]")
        matched = [issue for issue in issues if ALERT_MARKER in (issue.get("body") or "")]
        return sorted(matched, key=lambda issue: int(issue["number"]))

    def create_issue(self, title: str, body: str, labels: list[str]) -> dict[str, Any]:
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8") as tmp:
            tmp.write(body)
            tmp_path = tmp.name
        try:
            cmd = ["issue", "create", *self._repo_args(), "--title", title, "--body-file", tmp_path]
            for label in labels:
                cmd.extend(["--label", label])
            res = self._run(cmd)
            url = res.stdout.strip().splitlines()[-1].strip()
            number = int(url.rstrip("/").split("/")[-1])
            return {"number": number, "url": url, "title": title, "labels": [{"name": label} for label in labels]}
        finally:
            Path(tmp_path).unlink(missing_ok=True)

    def comment_issue(self, number: int, body: str) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8") as tmp:
            tmp.write(body)
            tmp_path = tmp.name
        try:
            self._run(["issue", "comment", str(number), *self._repo_args(), "--body-file", tmp_path])
        finally:
            Path(tmp_path).unlink(missing_ok=True)

    def close_issue(self, number: int, reason: str = "completed") -> None:
        self._run(["issue", "close", str(number), *self._repo_args(), "--reason", reason])


def evaluate_needs(needs: dict[str, Any]) -> tuple[str, list[dict[str, str]]]:
    """Classify daily workflow needs into ('failed', jobs), ('passed', []), or ('inconclusive', [])."""
    failed_jobs: list[dict[str, str]] = []
    results: dict[str, str] = {}
    for job_id, display_name in TRACKED_JOBS:
        entry = needs.get(job_id)
        result = str(entry.get("result") or "").strip().lower() if isinstance(entry, dict) else ""
        results[job_id] = result
        if result == "failure":
            failed_jobs.append({"id": job_id, "name": display_name, "result": result})

    if failed_jobs:
        return "failed", failed_jobs
    if all(results[job_id] == "success" for job_id, _ in TRACKED_JOBS):
        return "passed", []
    return "inconclusive", []


def _short_sha(sha: str) -> str:
    clean = sha.strip()
    return clean[:12] if clean else "unknown"


def render_issue_body(
    *,
    sha: str,
    run_url: str,
    failed_jobs: list[dict[str, str]],
    branch: str = "daily",
) -> str:
    job_lines = [f"- **{job['name']}** (`{job['id']}`): `{job['result']}`" for job in failed_jobs]
    lines = [
        ALERT_MARKER,
        "",
        f"A `Pull Request` workflow run on the `{branch}` release channel failed. "
        "This blocks deploying the failing commit to `foodsavr-test-daily` and blocks downstream promotions until resolved.",
        "",
        "## Latest Failure",
        "",
        f"- **Branch:** `{branch}`",
        f"- **Commit SHA:** `{sha or 'unknown'}`",
        f"- **Workflow Run:** {run_url or 'n/a'}",
        "",
        "### Failing Jobs",
        *job_lines,
        "",
        "This issue updates automatically on subsequent `daily` failures and closes once a `daily` run passes cleanly.",
    ]
    return "\n".join(lines) + "\n"


def render_failure_comment(
    *,
    sha: str,
    run_url: str,
    failed_jobs: list[dict[str, str]],
    branch: str = "daily",
) -> str:
    job_lines = [f"- **{job['name']}** (`{job['id']}`): `{job['result']}`" for job in failed_jobs]
    lines = [
        f"### Daily CI Still Failing (`{_short_sha(sha)}`)",
        "",
        f"- **Branch:** `{branch}`",
        f"- **Commit SHA:** `{sha or 'unknown'}`",
        f"- **Workflow Run:** {run_url or 'n/a'}",
        "",
        "#### Failing Jobs",
        *job_lines,
    ]
    return "\n".join(lines) + "\n"


def render_recovery_comment(*, sha: str, run_url: str, branch: str = "daily") -> str:
    lines = [
        f"### Daily CI Recovered (`{_short_sha(sha)}`)",
        "",
        f"- **Branch:** `{branch}`",
        f"- **Commit SHA:** `{sha or 'unknown'}`",
        f"- **Workflow Run:** {run_url or 'n/a'}",
        "",
        "All required `daily` checks (`Check & Test` and `Validation`) succeeded. Closing automatically.",
    ]
    return "\n".join(lines) + "\n"


def reconcile_daily_alert(
    *,
    needs: dict[str, Any],
    sha: str,
    run_url: str,
    gh: GhClient,
    branch: str = "daily",
    dry_run: bool = False,
) -> dict[str, Any]:
    """Open or comment on a deduplicated triage issue on failure, or close it on clean pass."""
    status, failed_jobs = evaluate_needs(needs)
    if status == "inconclusive":
        return {"status": status, "action": "noop", "failing_jobs": []}

    open_issues = gh.list_open_alert_issues()

    if status == "failed":
        if not open_issues:
            body = render_issue_body(sha=sha, run_url=run_url, failed_jobs=failed_jobs, branch=branch)
            created_num = None
            if not dry_run:
                created = gh.create_issue(ISSUE_TITLE, body, list(ISSUE_LABELS))
                created_num = int(created["number"])
            return {
                "status": status,
                "action": "would_create" if dry_run else "created",
                "issue": created_num,
                "labels": list(ISSUE_LABELS),
                "failing_jobs": [job["name"] for job in failed_jobs],
            }

        existing = open_issues[0]
        number = int(existing["number"])
        comment = render_failure_comment(sha=sha, run_url=run_url, failed_jobs=failed_jobs, branch=branch)
        if not dry_run:
            gh.comment_issue(number, comment)
        return {
            "status": status,
            "action": "would_comment" if dry_run else "commented",
            "issue": number,
            "failing_jobs": [job["name"] for job in failed_jobs],
        }

    # status == "passed"
    if not open_issues:
        return {"status": status, "action": "noop", "closed": []}

    comment = render_recovery_comment(sha=sha, run_url=run_url, branch=branch)
    closed: list[int] = []
    for issue in open_issues:
        number = int(issue["number"])
        if not dry_run:
            gh.comment_issue(number, comment)
            gh.close_issue(number, reason="completed")
        closed.append(number)
    return {
        "status": status,
        "action": "would_close" if dry_run else "closed",
        "closed": closed,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=None, help="GitHub owner/repo override")
    parser.add_argument("--sha", default=os.environ.get("COMMIT_SHA", ""), help="Checked commit SHA")
    parser.add_argument("--branch", default=os.environ.get("BRANCH_NAME", "daily"), help="Release branch name")
    parser.add_argument("--run-url", default=os.environ.get("RUN_URL", ""), help="GitHub Actions workflow run URL")
    parser.add_argument("--needs-json", default=None, help="JSON object from GitHub Actions `toJSON(needs)`")
    parser.add_argument("--dry-run", action="store_true", help="Report intended action without mutating issues")
    parser.add_argument(
        "--soft-fail",
        action="store_true",
        help="Warn and exit 0 on transient GitHub CLI/API errors so Pull Request checks stay green",
    )
    args = parser.parse_args(argv)

    raw_needs = args.needs_json if args.needs_json is not None else os.environ.get("NEEDS_JSON", "")
    if not raw_needs.strip():
        parser.error("Provide --needs-json or set NEEDS_JSON")
        return 2
    try:
        needs = json.loads(raw_needs)
    except json.JSONDecodeError as exc:
        parser.error(f"Invalid NEEDS_JSON: {exc}")
        return 2
    if not isinstance(needs, dict):
        parser.error("NEEDS_JSON must decode to a JSON object")
        return 2

    gh = SubprocessGhClient(repo=args.repo)
    try:
        result = reconcile_daily_alert(
            needs=needs,
            sha=args.sha,
            run_url=args.run_url,
            gh=gh,
            branch=args.branch,
            dry_run=args.dry_run,
        )
    except (subprocess.CalledProcessError, OSError) as exc:
        if args.soft_fail:
            detail = exc.stderr.strip() if isinstance(exc, subprocess.CalledProcessError) and exc.stderr else str(exc)
            print(f"::warning::Daily CI triage alert skipped after GitHub API error: {detail}", file=sys.stderr)
            return 0
        raise

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
