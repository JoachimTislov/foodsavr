#!/usr/bin/env python3
"""Unit tests for daily CI triage issue creation, deduplication, and auto-closure."""

from __future__ import annotations

import io
import json
import subprocess
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from typing import Any
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.github import daily_ci_alert as alert  # noqa: E402
from scripts.github import sync_labels  # noqa: E402


class FakeGhClient:
    def __init__(self, issues: list[dict[str, Any]] | None = None) -> None:
        self.issues: list[dict[str, Any]] = list(issues or [])
        self.created: list[dict[str, Any]] = []
        self.comments: list[tuple[int, str]] = []
        self.closed: list[tuple[int, str]] = []
        self._next_number = 600

    def list_open_alert_issues(self) -> list[dict[str, Any]]:
        matched = [
            issue
            for issue in self.issues
            if issue.get("state", "open") == "open" and alert.ALERT_MARKER in (issue.get("body") or "")
        ]
        return sorted(matched, key=lambda issue: int(issue["number"]))

    def create_issue(self, title: str, body: str, labels: list[str]) -> dict[str, Any]:
        num = self._next_number
        self._next_number += 1
        issue = {
            "number": num,
            "title": title,
            "body": body,
            "labels": [{"name": label} for label in labels],
            "state": "open",
            "url": f"https://github.com/example/foodsavr/issues/{num}",
        }
        self.issues.append(issue)
        self.created.append(issue)
        return issue

    def comment_issue(self, number: int, body: str) -> None:
        self.comments.append((number, body))

    def close_issue(self, number: int, reason: str = "completed") -> None:
        self.closed.append((number, reason))
        for issue in self.issues:
            if int(issue["number"]) == number:
                issue["state"] = "closed"


def _needs(
    *,
    gate: str = "success",
    check: str = "success",
    changes: str = "success",
    web_validation: str = "success",
    validation_result: str = "success",
) -> dict[str, dict[str, str]]:
    return {
        "gate": {"result": gate},
        "check": {"result": check},
        "changes": {"result": changes},
        "web-validation": {"result": web_validation},
        "validation-result": {"result": validation_result},
    }


class DailyCiAlertTest(unittest.TestCase):
    def test_labels_are_valid_repo_labels_and_title_keeps_type_bug(self) -> None:
        config = json.loads((ROOT / ".agents/github/labels.json").read_text(encoding="utf-8"))
        configured = {item["name"] for item in config["labels"]}
        for label in alert.ISSUE_LABELS:
            self.assertIn(label, configured)
        desired = sync_labels.classify(
            {
                "title": alert.ISSUE_TITLE,
                "body": alert.ALERT_MARKER,
                "labels": [{"name": label} for label in alert.ISSUE_LABELS],
                "is_pull_request": False,
            },
            [],
            [],
            [],
            config,
        )
        self.assertEqual(desired, set(alert.ISSUE_LABELS))

    def test_creates_triage_issue_when_daily_check_or_validation_fails(self) -> None:
        gh = FakeGhClient()
        res = alert.reconcile_daily_alert(
            needs=_needs(check="failure", web_validation="failure", validation_result="failure"),
            sha="1111111111111111111111111111111111111111",
            run_url="https://github.com/example/foodsavr/actions/runs/101",
            gh=gh,
        )
        self.assertEqual(res["status"], "failed")
        self.assertEqual(res["action"], "created")
        self.assertEqual(res["issue"], 600)
        self.assertEqual(res["labels"], ["type/bug", "area/ci"])
        self.assertEqual(res["failing_jobs"], ["Check & Test", "Web validation", "Validation status (result)"])
        self.assertEqual(len(gh.created), 1)
        body = gh.created[0]["body"]
        self.assertIn(alert.ALERT_MARKER, body)
        self.assertIn("1111111111111111111111111111111111111111", body)
        self.assertIn("https://github.com/example/foodsavr/actions/runs/101", body)
        self.assertIn("Check & Test", body)
        self.assertIn("Web validation", body)

    def test_deduplicates_and_comments_on_existing_open_issue(self) -> None:
        gh = FakeGhClient(
            issues=[
                {
                    "number": 541,
                    "title": alert.ISSUE_TITLE,
                    "body": f"{alert.ALERT_MARKER}\nold failure",
                    "state": "open",
                },
                {
                    "number": 542,
                    "title": "unrelated bug",
                    "body": "no marker here",
                    "state": "open",
                },
            ]
        )
        res = alert.reconcile_daily_alert(
            needs=_needs(check="failure"),
            sha="2222222222222222222222222222222222222222",
            run_url="https://github.com/example/foodsavr/actions/runs/202",
            gh=gh,
        )
        self.assertEqual(res["action"], "commented")
        self.assertEqual(res["issue"], 541)
        self.assertEqual(gh.created, [])
        self.assertEqual(len(gh.comments), 1)
        num, comment = gh.comments[0]
        self.assertEqual(num, 541)
        self.assertIn("2222222222222222222222222222222222222222", comment)
        self.assertIn("https://github.com/example/foodsavr/actions/runs/202", comment)
        self.assertIn("Check & Test", comment)

    def test_closes_open_issue_on_clean_daily_pass(self) -> None:
        gh = FakeGhClient(
            issues=[
                {
                    "number": 541,
                    "title": alert.ISSUE_TITLE,
                    "body": f"{alert.ALERT_MARKER}\nfailure",
                    "state": "open",
                }
            ]
        )
        res = alert.reconcile_daily_alert(
            needs=_needs(),
            sha="3333333333333333333333333333333333333333",
            run_url="https://github.com/example/foodsavr/actions/runs/303",
            gh=gh,
        )
        self.assertEqual(res, {"status": "passed", "action": "closed", "closed": [541]})
        self.assertEqual(gh.closed, [(541, "completed")])
        self.assertEqual(len(gh.comments), 1)
        self.assertIn("3333333333333333333333333333333333333333", gh.comments[0][1])
        self.assertIn("https://github.com/example/foodsavr/actions/runs/303", gh.comments[0][1])

    def test_clean_pass_without_open_issue_is_noop(self) -> None:
        gh = FakeGhClient()
        res = alert.reconcile_daily_alert(
            needs=_needs(),
            sha="4444444444444444444444444444444444444444",
            run_url="https://github.com/example/foodsavr/actions/runs/404",
            gh=gh,
        )
        self.assertEqual(res, {"status": "passed", "action": "noop", "closed": []})
        self.assertEqual(gh.created, [])
        self.assertEqual(gh.comments, [])
        self.assertEqual(gh.closed, [])

    def test_cancelled_run_without_failure_is_inconclusive_noop(self) -> None:
        gh = FakeGhClient(
            issues=[
                {
                    "number": 541,
                    "title": alert.ISSUE_TITLE,
                    "body": f"{alert.ALERT_MARKER}\nfailure",
                    "state": "open",
                }
            ]
        )
        res = alert.reconcile_daily_alert(
            needs=_needs(web_validation="cancelled", validation_result="skipped"),
            sha="5555555555555555555555555555555555555555",
            run_url="https://github.com/example/foodsavr/actions/runs/505",
            gh=gh,
        )
        self.assertEqual(res, {"status": "inconclusive", "action": "noop", "failing_jobs": []})
        self.assertEqual(gh.created, [])
        self.assertEqual(gh.comments, [])
        self.assertEqual(gh.closed, [])

    def test_soft_fail_warns_and_exits_zero_on_transient_gh_error(self) -> None:
        err = subprocess.CalledProcessError(1, ["gh", "issue", "list"], stderr="HTTP 502 Bad Gateway")
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(alert.SubprocessGhClient, "list_open_alert_issues", side_effect=err), \
                redirect_stdout(stdout), redirect_stderr(stderr):
            code = alert.main(
                [
                    "--sha",
                    "6666666666666666666666666666666666666666",
                    "--run-url",
                    "https://github.com/example/foodsavr/actions/runs/606",
                    "--needs-json",
                    json.dumps(_needs()),
                    "--soft-fail",
                ]
            )
        self.assertEqual(code, 0)
        self.assertIn("::warning::", stderr.getvalue())
        self.assertIn("502 Bad Gateway", stderr.getvalue())

    def test_without_soft_fail_propagates_gh_error(self) -> None:
        err = subprocess.CalledProcessError(1, ["gh", "issue", "list"], stderr="HTTP 502 Bad Gateway")
        with patch.object(alert.SubprocessGhClient, "list_open_alert_issues", side_effect=err):
            with self.assertRaises(subprocess.CalledProcessError):
                alert.main(
                    [
                        "--sha",
                        "6666666666666666666666666666666666666666",
                        "--needs-json",
                        json.dumps(_needs()),
                    ]
                )


if __name__ == "__main__":
    unittest.main()
