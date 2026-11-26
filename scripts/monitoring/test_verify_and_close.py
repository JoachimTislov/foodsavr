#!/usr/bin/env python3
"""Unit tests for verify_and_close post-deploy closure and escalation."""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

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
