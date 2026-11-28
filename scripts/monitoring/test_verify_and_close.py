#!/usr/bin/env python3
"""Unit tests for verify_and_close post-deploy closure and escalation."""

import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.monitoring import verify_and_close as vac  # noqa: E402
from scripts.monitoring.test_fault_intake import FakeGhClient  # noqa: E402
from scripts.monitoring.verify_and_close import pr_resolves_issue, verify_and_close  # noqa: E402

RELEASE_SHA = "a" * 40


class VerifyAndCloseTest(unittest.TestCase):
    def test_pr_resolves_issue_matches_keywords_or_branch(self):
        self.assertTrue(pr_resolves_issue({"body": "Closes: #42", "headRefName": "fix/x"}, 42))
        self.assertTrue(pr_resolves_issue({"body": "Fixes #42", "headRefName": "fix/x"}, 42))
        self.assertTrue(pr_resolves_issue({"body": "", "headRefName": "agent/issue-42"}, 42))
        self.assertFalse(pr_resolves_issue({"body": "Related to #420", "headRefName": "fix/420"}, 42))

    def test_closes_resolved_issue_on_clean_probe(self):
        gh = FakeGhClient(
            issues=[
                {
                    "number": 400,
                    "body": "<!-- healing-fingerprint:sha256:" + ("a" * 64) + " -->",
                    "labels": [{"name": "type/bug"}],
                },
                {
                    "number": 401,
                    "body": "<!-- healing-fingerprint:sha256:" + ("b" * 64) + " -->",
                    "labels": [{"name": "type/bug"}],
                },
            ]
        )
        gh.merged_prs[400] = [
            {
                "number": 410,
                "url": "https://github.com/JoachimTislov/foodsavr/pull/410",
                "body": "Closes: #400",
                "headRefName": "agent/issue-400",
            }
        ]
        res = verify_and_close(
            probe_ok=True,
            target_url="https://example-project.web.app",
            deployed_sha=RELEASE_SHA,
            served_revision=RELEASE_SHA,
            run_url="https://github.com/JoachimTislov/foodsavr/actions/runs/999",
            gh=gh,
        )
        self.assertEqual(
            res["actions"],
            [
                {"issue": 400, "action": "closed", "prs": [410]},
                {"issue": 401, "action": "skipped_no_merged_pr"},
            ],
        )
        self.assertEqual(gh.closed, [(400, "completed")])
        self.assertIn(RELEASE_SHA, gh.added_comments[0][1])
        self.assertIn("**Environment:** `production`", gh.added_comments[0][1])

    def test_clean_test_probe_never_closes_production_healing_issue(self):
        gh = FakeGhClient(
            issues=[
                {
                    "number": 420,
                    "body": (
                        "<!-- healing-fingerprint:sha256:" + ("a" * 64) + " -->\n"
                        "<!-- healing-environment:production -->\n"
                    ),
                    "labels": [{"name": "type/bug"}],
                },
                {
                    "number": 421,
                    "body": (
                        "<!-- healing-fingerprint:sha256:" + ("b" * 64) + " -->\n"
                        "| Environment | `production` |\n"
                    ),
                    "labels": [{"name": "type/bug"}],
                },
                {
                    "number": 422,
                    "body": "<!-- healing-fingerprint:sha256:" + ("c" * 64) + " -->\n",
                    "labels": [{"name": "type/bug"}],
                },
                {
                    "number": 423,
                    "body": (
                        "<!-- healing-fingerprint:sha256:" + ("d" * 64) + " -->\n"
                        "<!-- healing-environment:test -->\n"
                    ),
                    "labels": [{"name": "type/bug"}],
                },
            ]
        )
        for num in (420, 421, 422, 423):
            gh.merged_prs[num] = [{"number": 500 + num, "body": f"Closes #{num}", "headRefName": f"agent/issue-{num}"}]

        res = verify_and_close(
            probe_ok=True,
            target_url="https://foodsavr-test-daily.web.app",
            deployed_sha=RELEASE_SHA,
            served_revision=RELEASE_SHA,
            run_url="https://github.com/JoachimTislov/foodsavr/actions/runs/1001",
            environment="test",
            gh=gh,
        )
        self.assertEqual(res["environment"], "test")
        self.assertEqual(gh.closed, [(423, "completed")])
        self.assertEqual(
            res["actions"],
            [
                {"issue": 420, "action": "skipped_environment_mismatch", "issue_environment": "production", "probe_environment": "test"},
                {"issue": 421, "action": "skipped_environment_mismatch", "issue_environment": "production", "probe_environment": "test"},
                {"issue": 422, "action": "skipped_environment_mismatch", "issue_environment": "production", "probe_environment": "test"},
                {"issue": 423, "action": "closed", "prs": [923]},
            ],
        )
        self.assertIn("**Environment:** `test`", gh.added_comments[0][1])

    def test_production_probe_leaves_test_issue_open_and_failing_test_never_escalates_production(self):
        gh = FakeGhClient(
            issues=[
                {
                    "number": 430,
                    "body": "<!-- healing-fingerprint:sha256:" + ("e" * 64) + " -->\n<!-- healing-environment:production -->\n",
                    "labels": [{"name": "type/bug"}, {"name": "triage/ready-for-agent"}],
                },
                {
                    "number": 431,
                    "body": "<!-- healing-fingerprint:sha256:" + ("f" * 64) + " -->\n<!-- healing-environment:test -->\n",
                    "labels": [{"name": "type/bug"}, {"name": "triage/ready-for-agent"}],
                },
            ],
            comments={430: [{"body": "<!-- healing-attempt:1 -->"}], 431: [{"body": "<!-- healing-attempt:1 -->"}]},
        )
        gh.merged_prs[430] = [{"number": 440, "body": "Closes #430", "headRefName": "agent/issue-430"}]
        gh.merged_prs[431] = [{"number": 441, "body": "Closes #431", "headRefName": "agent/issue-431"}]

        fail_test = verify_and_close(
            probe_ok=False,
            target_url="https://foodsavr-test.web.app",
            deployed_sha=RELEASE_SHA,
            served_revision=RELEASE_SHA,
            run_url="https://github.com/JoachimTislov/foodsavr/actions/runs/1002",
            environment="test",
            gh=gh,
        )
        self.assertEqual(
            fail_test["actions"],
            [
                {"issue": 430, "action": "skipped_environment_mismatch", "issue_environment": "production", "probe_environment": "test"},
                {"issue": 431, "action": "escalated"},
            ],
        )
        self.assertEqual(gh.label_edits, [(431, ["triage/ready-for-human"], ["triage/ready-for-agent"])])

        pass_prod = verify_and_close(
            probe_ok=True,
            target_url="https://foodsavr.web.app",
            deployed_sha=RELEASE_SHA,
            served_revision=RELEASE_SHA,
            run_url="https://github.com/JoachimTislov/foodsavr/actions/runs/1003",
            environment="production",
            gh=gh,
        )
        self.assertEqual(gh.closed, [(430, "completed")])
        self.assertEqual(
            pass_prod["actions"],
            [
                {"issue": 430, "action": "closed", "prs": [440]},
                {"issue": 431, "action": "skipped_environment_mismatch", "issue_environment": "test", "probe_environment": "production"},
            ],
        )

    def test_cli_reads_environment_from_probe_file_and_flag(self):
        gh = FakeGhClient(
            issues=[
                {
                    "number": 450,
                    "body": "<!-- healing-fingerprint:sha256:" + ("a" * 64) + " -->\n<!-- healing-environment:production -->\n",
                    "labels": [{"name": "type/bug"}],
                }
            ]
        )
        gh.merged_prs[450] = [{"number": 451, "body": "Closes #450", "headRefName": "agent/issue-450"}]
        report = {
            "ok": True,
            "target_url": "https://foodsavr-test-weekly.web.app",
            "environment": "test",
            "served_revision": RELEASE_SHA,
            "root_mounted": True,
            "raw_findings": {"page_errors": [], "console_errors": [], "http_5xx": []},
        }
        with tempfile.TemporaryDirectory() as tmp:
            probe_file = Path(tmp) / "probe.json"
            probe_file.write_text(json.dumps(report), encoding="utf-8")
            stdout = io.StringIO()
            with patch.object(vac, "SubprocessGhClient", return_value=gh), redirect_stdout(stdout):
                code = vac.main(
                    [
                        "--probe-file",
                        str(probe_file),
                        "--target-url",
                        "https://foodsavr-test-weekly.web.app",
                        "--deployed-sha",
                        RELEASE_SHA,
                    ]
                )
        self.assertEqual(code, 0)
        payload = json.loads(stdout.getvalue())
        self.assertEqual(payload["environment"], "test")
        self.assertEqual(gh.closed, [])
        self.assertEqual(payload["actions"][0]["action"], "skipped_environment_mismatch")

    def test_never_closes_on_clean_health_alone(self):
        for expected, served in [
            (RELEASE_SHA, ""), (RELEASE_SHA, "b" * 40), ("", RELEASE_SHA), ("unknown", "unknown"),
        ]:
            with self.subTest(expected=expected, served=served):
                gh = FakeGhClient(issues=[{"number": 400}])
                gh.merged_prs[400] = [{"number": 410, "body": "Closes #400"}]
                result = verify_and_close(
                    probe_ok=True, target_url="https://example.com", deployed_sha=expected,
                    served_revision=served, gh=gh, run_url="",
                )
                self.assertIn("skipped", result)
                self.assertEqual(gh.closed, [])
                self.assertEqual(gh.added_comments, [])

    def test_escalates_issue_when_probe_still_fails_after_merged_pr(self):
        gh = FakeGhClient(
            issues=[
                {
                    "number": 402,
                    "body": "<!-- healing-fingerprint:sha256:" + ("c" * 64) + " -->",
                    "labels": [{"name": "type/bug"}, {"name": "triage/ready-for-agent"}],
                }
            ],
            comments={402: [{"body": "<!-- healing-attempt:1 -->"}]},
        )
        gh.merged_prs[402] = [
            {
                "number": 412,
                "url": "https://github.com/JoachimTislov/foodsavr/pull/412",
                "body": "Closes #402",
                "headRefName": "agent/issue-402",
            }
        ]
        res = verify_and_close(
            probe_ok=False,
            target_url="https://example-project.web.app",
            deployed_sha="badc0de",
            run_url="https://github.com/JoachimTislov/foodsavr/actions/runs/1000",
            gh=gh,
            max_attempts=1,
        )
        self.assertEqual(res["actions"], [{"issue": 402, "action": "escalated"}])
        self.assertEqual(gh.closed, [])
        self.assertIn("**Deployed SHA:** `unknown`", gh.added_comments[0][1])
        self.assertEqual(gh.label_edits, [(402, ["triage/ready-for-human"], ["triage/ready-for-agent"])])


if __name__ == "__main__":
    unittest.main()
