#!/usr/bin/env python3
"""Unit tests for fault_intake deduplication, circuit breakers, quarantine, and routing."""

import sys
import unittest
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.monitoring.fault_intake import process_events  # noqa: E402
from scripts.monitoring.fault_schema import make_fault_event  # noqa: E402


class FakeGhClient:
    def __init__(self, issues: list[dict[str, Any]] | None = None, comments: dict[int, list[dict[str, Any]]] | None = None):
        self.issues: list[dict[str, Any]] = issues or []
        self.comments: dict[int, list[dict[str, Any]]] = comments or {}
        self.created: list[dict[str, Any]] = []
        self.added_comments: list[tuple[int, str]] = []
        self.label_edits: list[tuple[int, list[str], list[str]]] = []
        self.dispatched: list[tuple[int, str]] = []
        self.closed: list[tuple[int, str]] = []
        self.merged_prs: dict[int, list[dict[str, Any]]] = {}
        self._next_number = 500

    def ensure_label(self, name: str) -> None:
        return None

    def list_open_healing_issues(self) -> list[dict[str, Any]]:
        return [i for i in self.issues if i.get("state", "open") == "open"]

    def get_issue_comments(self, number: int) -> list[dict[str, Any]]:
        return self.comments.get(number, [])

    def create_issue(self, title: str, body: str, labels: list[str]) -> dict[str, Any]:
        num = self._next_number
        self._next_number += 1
        issue = {
            "number": num,
            "title": title,
            "body": body,
            "labels": [{"name": l} for l in labels],
            "state": "open",
            "url": f"https://github.com/JoachimTislov/foodsavr/issues/{num}",
        }
        self.issues.append(issue)
        self.created.append(issue)
        return issue

    def comment_issue(self, number: int, body: str) -> None:
        self.added_comments.append((number, body))
        self.comments.setdefault(number, []).append({"body": body})

    def edit_issue_labels(
        self,
        number: int,
        *,
        add: list[str] | None = None,
        remove: list[str] | None = None,
    ) -> None:
        self.label_edits.append((number, add or [], remove or []))
        for issue in self.issues:
            if issue["number"] == number:
                names = {l["name"] for l in issue["labels"]}
                names.difference_update(remove or [])
                names.update(add or [])
                issue["labels"] = [{"name": n} for n in sorted(names)]

    def close_issue(self, number: int, reason: str = "completed") -> None:
        self.closed.append((number, reason))
        for issue in self.issues:
            if issue["number"] == number:
                issue["state"] = "closed"

    def list_merged_prs_for_issue(self, number: int) -> list[dict[str, Any]]:
        return self.merged_prs.get(number, [])

    def dispatch_healing(self, number: int, ref: str = "main") -> None:
        self.dispatched.append((number, ref))


class FaultIntakeTest(unittest.TestCase):
    def test_creates_and_dispatches_new_code_fault_with_quarantine(self):
        gh = FakeGhClient()
        ev = make_fault_event(
            source="github/playwright-probe",
            error_type="EmptyEnvFileError",
            message='Environment file "assets/.env" is empty. <!-- evil --> ```ignore```',
            url="https://foodsavr-test.web.app/",
        )
        res = process_events([ev], gh, dispatch=True, dry_run=False)
        self.assertEqual(res["processed"], 1)
        self.assertEqual(res["results"][0]["action"], "created_and_dispatched")
        self.assertEqual(len(gh.created), 1)
        body = gh.created[0]["body"]
        self.assertIn(f"<!-- healing-fingerprint:{ev.fingerprint} -->", body)
        self.assertIn("Quarantine Notice", body)
        self.assertNotIn("<!-- evil -->", body)
        self.assertNotIn("```ignore```", body)
        self.assertEqual(gh.dispatched, [(500, "main")])
        self.assertTrue(any("<!-- healing-attempt:1 -->" in c[1] for c in gh.added_comments))

    def test_deduplicates_against_open_issue_and_escalates_after_attempt_cap(self):
        ev = make_fault_event(
            source="github/playwright-probe",
            error_type="EmptyEnvFileError",
            message='Environment file "assets/.env" is empty.',
        )
        gh = FakeGhClient(
            issues=[
                {
                    "number": 301,
                    "title": "heal(web): EmptyEnvFileError",
                    "body": f"<!-- healing-fingerprint:{ev.fingerprint} -->\n",
                    "labels": [{"name": "type/bug"}, {"name": "triage/ready-for-agent"}],
                }
            ],
            comments={301: []},
        )
        first = process_events([ev], gh, dispatch=True, max_attempts=1)
        self.assertEqual(first["results"][0]["action"], "deduplicated")
        self.assertEqual(len(gh.created), 0)
        self.assertEqual(len(gh.dispatched), 0)
        self.assertEqual(len(gh.added_comments), 1)

        # Now simulate that 1 autonomous attempt already ran and fault still recurs
        gh.comments[301].append({"body": "<!-- healing-attempt:1 -->"})
        second = process_events([ev], gh, dispatch=True, max_attempts=1)
        self.assertEqual(second["results"][0]["action"], "escalated")
        self.assertEqual(gh.label_edits, [(301, ["triage/ready-for-human"], ["triage/ready-for-agent"])])

    def test_quota_and_infrastructure_never_dispatch_to_agent(self):
        gh = FakeGhClient()
        quota_ev = make_fault_event(
            source="firebase/spark-firestore",
            error_type="FirebaseException",
            message="RESOURCE_EXHAUSTED: Firestore daily quota exceeded",
        )
        infra_ev = make_fault_event(
            source="checkly",
            error_type="HttpError",
            message="503 Service Unavailable",
            status_code=503,
        )
        res = process_events([quota_ev, infra_ev], gh, dispatch=True)
        self.assertEqual([r["action"] for r in res["results"]], ["created_human_triage", "created_human_triage"])
        self.assertEqual(gh.dispatched, [])
        for issue in gh.created:
            labels = {l["name"] for l in issue["labels"]}
            self.assertIn("triage/ready-for-human", labels)

    def test_circuit_breaker_caps_concurrent_open_healing_issues(self):
        existing = [
            {"number": i, "title": f"heal {i}", "body": f"<!-- healing-fingerprint:sha256:{str(i)*64} -->", "labels": []}
            for i in range(1, 4)
        ]
        gh = FakeGhClient(issues=existing)
        ev = make_fault_event(source="github/playwright-probe", error_type="TypeError", message="boom")
        res = process_events([ev], gh, dispatch=True, max_open=3)
        self.assertEqual(res["results"][0]["action"], "circuit_breaker_held")
        self.assertEqual(gh.dispatched, [])
        self.assertIn("Open healing issue limit reached", gh.created[0]["body"])

    def test_dry_run_makes_no_mutations(self):
        gh = FakeGhClient()
        ev = make_fault_event(source="github/playwright-probe", error_type="TypeError", message="boom")
        res = process_events([ev], gh, dispatch=True, dry_run=True)
        self.assertEqual(res["results"][0]["action"], "would_create_and_dispatch")
        self.assertEqual(gh.created, [])
        self.assertEqual(gh.dispatched, [])
        self.assertEqual(gh.added_comments, [])


if __name__ == "__main__":
    unittest.main()
