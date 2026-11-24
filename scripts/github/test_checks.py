#!/usr/bin/env python3
import importlib.util
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts/github"))
import checks  # noqa: E402

spec = importlib.util.spec_from_file_location("merge_gate", ROOT / "scripts/github/merge_gate.py")
gate = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["merge_gate"] = gate
spec.loader.exec_module(gate)

T0 = datetime(2026, 11, 21, 12, 0, tzinfo=timezone.utc)


def at(minutes):
    return (T0 + timedelta(minutes=minutes)).strftime("%Y-%m-%dT%H:%M:%SZ")


def run(conclusion, minutes=0, name="Check & Test", workflow="Validation", status="COMPLETED", started=True, run_id=None):
    c = {
        "__typename": "CheckRun",
        "name": name,
        "status": status,
        "conclusion": conclusion,
        "checkSuite": {"app": {"slug": "github-actions"}, "workflowRun": {"workflow": {"name": workflow}}},
    }
    if started:
        c["startedAt"] = at(minutes)
    if run_id is not None:
        c["checkSuite"]["workflowRun"]["databaseId"] = run_id
    return c


class EffectiveRunTest(unittest.TestCase):
    def state(self, *runs):
        return checks.rollup_state(list(runs))

    def test_newer_success_supersedes_cancelled(self):
        self.assertEqual(self.state(run("CANCELLED", 0), run("SUCCESS", 1)), "SUCCESS")

    def test_input_order_does_not_matter(self):
        self.assertEqual(self.state(run("SUCCESS", 1), run("CANCELLED", 0)), "SUCCESS")

    def test_newer_failure_supersedes_success(self):
        self.assertEqual(self.state(run("SUCCESS", 0), run("FAILURE", 1)), "FAILURE")

    def test_newer_success_supersedes_failure(self):
        self.assertEqual(self.state(run("FAILURE", 0), run("SUCCESS", 1)), "SUCCESS")

    def test_newer_skipped_does_not_hide_failure(self):
        self.assertEqual(self.state(run("FAILURE", 0), run("SKIPPED", 1)), "FAILURE")

    def test_newer_skipped_does_not_hide_success(self):
        self.assertEqual(self.state(run("SUCCESS", 0), run("SKIPPED", 1)), "SUCCESS")

    def test_newer_skipped_does_not_hide_cancelled(self):
        self.assertEqual(self.state(run("CANCELLED", 0), run("SKIPPED", 1)), "FAILURE")

    def test_all_skipped_uses_latest_skipped(self):
        kept = checks.effective_runs([run("SKIPPED", 0), run("SKIPPED", 2), run("SKIPPED", 1)])
        self.assertEqual([c["startedAt"] for c in kept], [at(2)])
        self.assertEqual(self.state(run("SKIPPED", 0), run("SKIPPED", 1)), "SUCCESS")

    def test_in_progress_newer_run_is_pending(self):
        self.assertEqual(self.state(run("SUCCESS", 0), run(None, 1, status="IN_PROGRESS")), "PENDING")
        self.assertEqual(self.state(run("FAILURE", 0), run(None, 1, status="QUEUED")), "PENDING")

    def test_older_in_progress_run_is_superseded(self):
        self.assertEqual(self.state(run(None, 0, status="IN_PROGRESS"), run("SUCCESS", 1)), "SUCCESS")

    def test_missing_started_at_keeps_every_run(self):
        runs = [run("CANCELLED", started=False), run("SUCCESS", started=False)]
        self.assertEqual(len(checks.effective_runs(runs)), 2)
        self.assertEqual(self.state(*runs), "FAILURE")

    def test_one_run_without_started_at_disables_selection_for_that_key(self):
        runs = [run("CANCELLED", 0, started=False), run("SUCCESS", 1)]
        self.assertEqual(self.state(*runs), "FAILURE")

    def test_same_check_name_in_different_workflows_stays_separate(self):
        self.assertEqual(self.state(run("FAILURE", 0, workflow="Validation"), run("SUCCESS", 1, workflow="CI")), "FAILURE")

    def test_different_check_names_stay_separate(self):
        self.assertEqual(self.state(run("FAILURE", 0, name="a"), run("SUCCESS", 1, name="b")), "FAILURE")

    def test_status_contexts_are_keyed_by_context_name(self):
        status = lambda ctx, state: {"__typename": "StatusContext", "context": ctx, "state": state}
        self.assertEqual(checks.rollup_state([status("x", "FAILURE"), status("y", "SUCCESS")]), "FAILURE")
        self.assertEqual(len(checks.effective_runs([status("x", "FAILURE"), status("x", "SUCCESS")])), 2)

    def test_queue_check_uses_effective_run(self):
        q = lambda conclusion, minutes, **kw: run(conclusion, minutes, name=checks.QUEUE_CHECK, **kw)
        self.assertEqual(checks.queue_check_state([q("CANCELLED", 0), q("SUCCESS", 1)]), (True, False))
        self.assertEqual(checks.queue_check_state([q("SUCCESS", 0), q("SKIPPED", 1)]), (True, False))
        self.assertEqual(checks.queue_check_state([q("SUCCESS", 0), q(None, 1, status="IN_PROGRESS")]), (False, True))

    def test_review_check_running_tracks_active_trusted_agent_review(self):
        rev = lambda conclusion, minutes, **kw: run(conclusion, minutes, name="Review PR", workflow=checks.REVIEW_WORKFLOW, **kw)
        self.assertTrue(checks.review_check_running([rev(None, 1, status="IN_PROGRESS")]))
        self.assertTrue(checks.review_check_running([rev("SUCCESS", 0), rev(None, 1, status="QUEUED")]))
        self.assertFalse(checks.review_check_running([rev(None, 0, status="IN_PROGRESS"), rev("SUCCESS", 1)]))
        self.assertFalse(checks.review_check_running([run(None, 1, status="IN_PROGRESS", workflow="Validation")]))
        untrusted = rev(None, 1, status="IN_PROGRESS")
        untrusted["checkSuite"]["app"]["slug"] = "rogue-app"
        self.assertFalse(checks.review_check_running([untrusted]))


HOLD = "Validation status (hold)"


def pr409_sequence():
    """Push starts run A (hold executes), labeling starts run B which cancels A and skips hold."""
    return [
        run("CANCELLED", 0, name=HOLD, run_id=100),
        run("SKIPPED", 2, name=HOLD, run_id=101),
        run("SUCCESS", 0, name="Detect changed areas", run_id=100),
        run("SUCCESS", 3, name="Detect changed areas", run_id=101),
        run("SUCCESS", 1, run_id=100),
        run("SUCCESS", 4, run_id=101),
    ]


class SupersededCancelledTest(unittest.TestCase):
    def test_pr409_sequence_is_success(self):
        self.assertEqual(checks.rollup_state(pr409_sequence()), "SUCCESS")
        self.assertEqual(checks.rollup_state(list(reversed(pr409_sequence()))), "SUCCESS")

    def test_cancelled_without_newer_workflow_run_fails(self):
        self.assertEqual(checks.rollup_state([run("CANCELLED", 0, run_id=100), run("SUCCESS", 1, name="b", run_id=100)]), "FAILURE")

    def test_newer_run_of_other_workflow_does_not_supersede(self):
        runs = [run("CANCELLED", 0, run_id=100), run("SUCCESS", 1, workflow="CI", run_id=200)]
        self.assertEqual(checks.rollup_state(runs), "FAILURE")

    def test_older_run_of_same_workflow_does_not_hide_cancelled(self):
        runs = [run("SUCCESS", 0, name="b", run_id=100), run("CANCELLED", 1, run_id=101)]
        self.assertEqual(checks.rollup_state(runs), "FAILURE")

    def test_failure_is_never_superseded(self):
        runs = [run("FAILURE", 0, run_id=100), run("SKIPPED", 1, run_id=101)]
        self.assertEqual(checks.rollup_state(runs), "FAILURE")

    def test_missing_run_id_keeps_old_behavior(self):
        runs = [run("CANCELLED", 0, name=HOLD), run("SKIPPED", 2, name=HOLD, run_id=101)]
        self.assertEqual(checks.rollup_state(runs), "FAILURE")


class GatePlanTest(unittest.TestCase):
    def merged(self, *contexts):
        from test_merge_gate import NOW, pr

        p = pr(7, rollup=checks.rollup_state(list(contexts)))
        return [(a, x.number) for a, x in gate.plan([p], NOW).actions]

    def test_merges_when_older_cancelled_run_is_superseded_by_success(self):
        self.assertEqual(self.merged(run("CANCELLED", 0), run("SUCCESS", 1)), [("merge", 7)])

    def test_does_not_merge_when_skipped_run_sits_on_top_of_failure(self):
        self.assertEqual(self.merged(run("FAILURE", 0), run("SKIPPED", 1)), [])

    def test_gate_query_requests_started_at(self):
        self.assertIn("conclusion startedAt", gate.QUERY)

    def test_gate_query_requests_workflow_run_id(self):
        self.assertIn("workflowRun { databaseId", gate.QUERY)


if __name__ == "__main__":
    unittest.main()
