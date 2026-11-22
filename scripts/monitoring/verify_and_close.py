#!/usr/bin/env python3
"""Verify post-deploy probe health and close resolved healing issues or escalate failures."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.monitoring.fault_intake import (  # noqa: E402
    GhClient,
    SubprocessGhClient,
    count_healing_attempts,
)


def pr_resolves_issue(pr: dict[str, Any], issue_number: int) -> bool:
    """Return True if a merged PR explicitly closes/fixes/resolves the issue or uses its agent branch."""
    head_ref = str(pr.get("headRefName") or "")
    if head_ref in {f"agent/issue-{issue_number}", f"healing/issue-{issue_number}"}:
        return True
    body = str(pr.get("body") or "")
    pattern = re.compile(
        rf"\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s*:?\s*#{issue_number}\b",
        re.IGNORECASE,
    )
    return bool(pattern.search(body))


def _issue_labels(issue: dict[str, Any]) -> set[str]:
    return {
        str(item["name"]) if isinstance(item, dict) else str(item)
        for item in (issue.get("labels") or [])
    }


def verify_and_close(
    *,
    probe_ok: bool,
    target_url: str,
    deployed_sha: str,
    run_url: str,
    gh: GhClient,
    dry_run: bool = False,
    max_attempts: int = 1,
    probe_summary: str = "",
) -> dict[str, Any]:
    """Close resolved healing issues on clean post-deploy probe or escalate failures."""
    open_issues = gh.list_open_healing_issues()
    actions: list[dict[str, Any]] = []

    for issue in open_issues:
        number = int(issue["number"])
        merged_prs = [
            pr for pr in gh.list_merged_prs_for_issue(number) if pr_resolves_issue(pr, number)
        ]
        if not merged_prs:
            actions.append({"issue": number, "action": "skipped_no_merged_pr"})
            continue

        pr_refs = ", ".join(f"#{pr['number']} ({pr.get('url', '')})" for pr in merged_prs)
        if probe_ok:
            comment = (
                "### Post-Deploy Verification Passed\n\n"
                f"- **Target URL:** `{target_url}`\n"
                f"- **Deployed SHA:** `{deployed_sha or 'unknown'}`\n"
                f"- **Verification Run:** {run_url or 'n/a'}\n"
                f"- **Resolved By PR:** {pr_refs}\n"
                f"- **Probe Result:** {probe_summary or '0 page errors, 0 console errors, 0 HTTP 5xx, Flutter root mounted.'}\n"
            )
            if not dry_run:
                gh.comment_issue(number, comment)
                gh.close_issue(number, reason="completed")
            actions.append({"issue": number, "action": "would_close" if dry_run else "closed", "prs": [p["number"] for p in merged_prs]})
            continue

        # Probe failed even though a healing PR was merged.
        comments = gh.get_issue_comments(number)
        attempts = max(count_healing_attempts(comments), len(merged_prs))
        labels = _issue_labels(issue)
        already_escalated = "triage/ready-for-human" in labels

        if attempts >= max_attempts and not already_escalated:
            comment = (
                "### Post-Deploy Verification Failed — Escalated\n\n"
                f"- **Target URL:** `{target_url}`\n"
                f"- **Deployed SHA:** `{deployed_sha or 'unknown'}`\n"
                f"- **Verification Run:** {run_url or 'n/a'}\n"
                f"- **Merged PR:** {pr_refs}\n"
                f"- **Details:** {probe_summary or 'Live probe failed after merged fix.'}\n\n"
                f"Escalating to `triage/ready-for-human` (automated fix attempt cap {max_attempts} reached).\n"
            )
            if not dry_run:
                gh.comment_issue(number, comment)
                remove = ["triage/ready-for-agent"] if "triage/ready-for-agent" in labels else []
                gh.edit_issue_labels(number, add=["triage/ready-for-human"], remove=remove)
            actions.append({"issue": number, "action": "would_escalate" if dry_run else "escalated"})
        else:
            comment = (
                "### Post-Deploy Verification Failed\n\n"
                f"- **Target URL:** `{target_url}`\n"
                f"- **Deployed SHA:** `{deployed_sha or 'unknown'}`\n"
                f"- **Verification Run:** {run_url or 'n/a'}\n"
                f"- **Details:** {probe_summary or 'Live probe failed.'}\n"
            )
            if not dry_run:
                gh.comment_issue(number, comment)
            actions.append({"issue": number, "action": "would_record_failure" if dry_run else "recorded_failure"})

    return {"probe_ok": probe_ok, "dry_run": dry_run, "actions": actions}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--probe-file", default=None, help="JSON output from probe_web.mjs")
    parser.add_argument("--passed", action="store_true", help="Mark verification passed (when no --probe-file)")
    parser.add_argument("--failed", action="store_true", help="Mark verification failed (when no --probe-file)")
    parser.add_argument("--target-url", default="")
    parser.add_argument("--deployed-sha", default="")
    parser.add_argument("--run-url", default="")
    parser.add_argument("--repo", default=None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--max-attempts", type=int, default=1)
    args = parser.parse_args(argv)

    probe_summary = ""
    if args.probe_file:
        report = json.loads(Path(args.probe_file).read_text(encoding="utf-8"))
        probe_ok = bool(report.get("ok"))
        target_url = args.target_url or str(report.get("target_url") or "")
        deployed_sha = args.deployed_sha or str(report.get("release_sha") or "")
        raw = report.get("raw_findings") or {}
        probe_summary = (
            f"root_mounted={report.get('root_mounted')}, "
            f"page_errors={len(raw.get('page_errors') or [])}, "
            f"console_errors={len(raw.get('console_errors') or [])}, "
            f"http_5xx={len(raw.get('http_5xx') or [])}"
        )
    elif args.passed or args.failed:
        probe_ok = bool(args.passed and not args.failed)
        target_url = args.target_url
        deployed_sha = args.deployed_sha
    else:
        parser.error("Specify --probe-file or --passed / --failed")
        return 2

    gh = SubprocessGhClient(repo=args.repo)
    result = verify_and_close(
        probe_ok=probe_ok,
        target_url=target_url,
        deployed_sha=deployed_sha,
        run_url=args.run_url,
        gh=gh,
        dry_run=args.dry_run,
        max_attempts=args.max_attempts,
        probe_summary=probe_summary,
    )
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
