#!/usr/bin/env python3
import importlib.util
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("promote_main", ROOT / "scripts/github/promote_main.py")
promote = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["promote_main"] = promote
spec.loader.exec_module(promote)


def check_run(name, status="COMPLETED", conclusion="SUCCESS", workflow=None):
    node = {"__typename": "CheckRun", "name": name, "status": status, "conclusion": conclusion}
    if workflow is not None:
        node["checkSuite"] = {"workflowRun": {"workflow": {"name": workflow}}}
    return node


class PromoteDecisionTest(unittest.TestCase):
    def test_noop_when_shas_match(self):
        d = promote.decide_promotion("abcdef1", "abcdef1", True, [])
        self.assertEqual(d.action, "noop")

    def test_blocks_non_fast_forward(self):
        d = promote.decide_promotion("abcdef1", "1234567", False, [check_run("Detect changed areas")])
        self.assertEqual(d.action, "blocked")

    def test_blocks_on_failed_check_or_status_context(self):
        d = promote.decide_promotion(
            "abcdef1",
            "1234567",
            True,
            [check_run("Detect changed areas"), check_run("Check & Test", conclusion="FAILURE")],
        )
        self.assertEqual(d.action, "blocked")
        d_status = promote.decide_promotion(
            "abcdef1",
            "1234567",
            True,
            [check_run("Detect changed areas"), {"__typename": "StatusContext", "context": "ci", "state": "FAILURE"}],
        )
        self.assertEqual(d_status.action, "blocked")

    def test_pending_while_checks_run_or_validation_missing(self):
        d = promote.decide_promotion(
            "abcdef1",
            "1234567",
            True,
            [check_run("Detect changed areas"), check_run("Web smoke test", status="IN_PROGRESS", conclusion=None)],
        )
        self.assertEqual(d.action, "pending")
        d2 = promote.decide_promotion("abcdef1", "1234567", True, [check_run("Check & Test")])
        self.assertEqual(d2.action, "pending")
        d3 = promote.decide_promotion(
            "abcdef1",
            "1234567",
            True,
            [check_run("Detect changed areas", conclusion="SKIPPED")],
        )
        self.assertEqual(d3.action, "pending")

    def test_ignores_metadata_and_self_workflows(self):
        d = promote.decide_promotion(
            "abcdef1",
            "1234567",
            True,
            [
                check_run("Detect changed areas", workflow="Validation"),
                check_run("Fast-forward main to green develop", status="IN_PROGRESS", conclusion=None, workflow="Promote develop to main"),
                check_run("Integrate ready PRs", status="IN_PROGRESS", conclusion=None, workflow="Merge gate"),
                check_run("sync", status="COMPLETED", conclusion="FAILURE", workflow="Synchronize GitHub labels"),
            ],
        )
        self.assertEqual(d.action, "promote")

    def test_promotes_when_validation_green_and_nothing_failed_or_pending(self):
        d = promote.decide_promotion(
            "abcdef1",
            "1234567",
            True,
            [check_run("Detect changed areas"), check_run("Web smoke test", conclusion="SKIPPED")],
        )
        self.assertEqual(d.action, "promote")


if __name__ == "__main__":
    unittest.main()
