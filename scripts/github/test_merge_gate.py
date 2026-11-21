#!/usr/bin/env python3
import importlib.util
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("merge_gate", ROOT / "scripts/github/merge_gate.py")
gate = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["merge_gate"] = gate
spec.loader.exec_module(gate)

NOW = datetime(2026, 11, 21, 12, 0, tzinfo=timezone.utc)


def pr(number, state="CLEAN", rollup="SUCCESS", labels=(gate.LABEL,), **kw):
    kw.setdefault("head_time", NOW - timedelta(minutes=5))
    return gate.PR(number=number, node_id=f"N{number}", title=kw.pop("title", "feat: x"), head=f"{number:07d}",
                   merge_state=state, rollup=rollup, labels=set(labels), **kw)


def actions(prs):
    return [(a, p.number) for a, p in gate.plan(prs, NOW).actions]


class PlanTest(unittest.TestCase):
    def test_merges_oldest_green_pr_only(self):
        self.assertEqual(actions([pr(3), pr(2)]), [("merge", 2)])

    def test_unlabeled_and_blocked_prs_are_left_alone(self):
        self.assertEqual(actions([pr(1, labels=()), pr(2, body="**Door:** one-way"), pr(3, state="DIRTY"),
                                  pr(4, open_threads=1), pr(5, review_decision="CHANGES_REQUESTED"),
                                  pr(6, rollup="FAILURE"), pr(7, draft=True), pr(8, fork=True)]), [])

    def test_non_required_failure_or_pending_check_blocks_merge(self):
        self.assertEqual(actions([pr(1, state="UNSTABLE", rollup="FAILURE")]), [])
        self.assertEqual(actions([pr(1, state="UNSTABLE")]), [("merge", 1)])
        self.assertEqual(actions([pr(1, rollup="PENDING", state="BLOCKED")]), [])

    def test_updates_one_behind_pr_when_nothing_in_flight(self):
        self.assertEqual(actions([pr(2, state="BEHIND"), pr(1, state="BEHIND")]), [("update", 1)])

    def test_waits_while_another_pr_runs_checks(self):
        self.assertEqual(actions([pr(1, state="BEHIND"), pr(2, state="BLOCKED", rollup="PENDING")]), [])

    def test_stalled_checks_do_not_hold_the_queue(self):
        stalled = pr(2, state="BLOCKED", rollup="PENDING", head_time=NOW - timedelta(hours=2))
        self.assertEqual(actions([pr(1, state="BEHIND"), stalled]), [("update", 1)])

    def test_dependabot_rebase_request_counts_as_in_flight(self):
        bot = pr(1, state="BEHIND", author="dependabot", bot=True, head_time=NOW - timedelta(hours=1),
                 rebase_requested=NOW - timedelta(minutes=5))
        self.assertEqual(actions([bot, pr(2, state="BEHIND")]), [])
        bot.rebase_requested = NOW - timedelta(hours=2)
        self.assertEqual(actions([bot, pr(2, state="BEHIND")]), [("update", 1)])

    def test_refused_dependabot_rebase_blocks_only_that_pr(self):
        refused = pr(1, state="BEHIND", author="dependabot", bot=True, rebase_refused=True,
                     rebase_requested=NOW - timedelta(minutes=5))
        self.assertEqual(actions([refused, pr(2, state="BEHIND")]), [("update", 2)])

    def test_human_named_dependabot_is_not_dependabot(self):
        fork = pr(1, labels=(), author="dependabot", fork=True, title="bump a from 1.0.0 to 1.0.1")
        self.assertEqual(actions([fork]), [])
        fork.labels = {gate.LABEL}
        self.assertEqual(actions([fork]), [])

    def test_dependabot_minor_and_patch_opt_in_unless_label_was_removed(self):
        def bot(n, title, **kw):
            return pr(n, labels=(), author="dependabot", bot=True, title=title, **kw)
        self.assertEqual(actions([bot(1, "bump a from 1.2.3 to 1.2.4"), bot(2, "bump b from 1.2.3 to 1.3.0"),
                                  bot(3, "bump c from 1.2.3 to 2.0.0"), bot(4, "bump d from 0.2.0 to 0.3.0"),
                                  bot(5, "bump e from 1.0.0 to 1.0.1", label_removed=True)]),
                         [("label", 1), ("label", 2)])


class ParseTest(unittest.TestCase):
    def test_rollup_state(self):
        run = lambda status, conclusion=None: {"__typename": "CheckRun", "name": "c", "status": status, "conclusion": conclusion}
        self.assertIsNone(gate.rollup_state([]))
        self.assertEqual(gate.rollup_state([run("COMPLETED", "SUCCESS"), run("QUEUED")]), "PENDING")
        self.assertEqual(gate.rollup_state([run("COMPLETED", "CANCELLED"), run("QUEUED")]), "FAILURE")
        self.assertEqual(gate.rollup_state([run("COMPLETED", "NEUTRAL"), {"__typename": "StatusContext", "state": "EXPECTED"}]), "PENDING")

    def test_from_node(self):
        node = {
            "id": "N", "number": 9, "title": "t", "body": None, "isDraft": False, "isCrossRepository": False,
            "mergeStateStatus": "BEHIND", "reviewDecision": None, "headRefOid": "abc",
            "author": {"__typename": "Bot", "login": "dependabot"}, "labels": {"nodes": [{"name": gate.LABEL}]},
            "reviewThreads": {"nodes": [{"isResolved": False, "isOutdated": True}, {"isResolved": False, "isOutdated": False}]},
            "commits": {"nodes": [{"commit": {"committedDate": "2026-11-21T10:00:00Z", "statusCheckRollup": {"contexts": {"nodes": [
                {"__typename": "CheckRun", "name": "Check & Test", "status": "COMPLETED", "conclusion": "SKIPPED"},
                {"__typename": "CheckRun", "name": gate.GATE_CHECK, "status": "IN_PROGRESS", "conclusion": None},
                {"__typename": "StatusContext", "context": "x", "state": "SUCCESS"}]}}}}]},
            "timelineItems": {"nodes": [{"label": {"name": "other"}}]},
            "comments": {"nodes": [
                {"body": "@dependabot rebase", "createdAt": "2026-11-21T11:00:00Z", "author": {"login": "owner"}},
                {"body": "Looks like this PR has been edited by someone other than Dependabot.",
                 "createdAt": "2026-11-21T11:00:05Z", "author": {"login": "dependabot"}}]},
        }
        p = gate.from_node(node)
        self.assertEqual((p.open_threads, p.label_removed, p.dependabot, p.rollup, p.rebase_refused),
                         (1, False, True, "SUCCESS", True))
        self.assertEqual(p.rebase_requested, datetime(2026, 11, 21, 11, 0, tzinfo=timezone.utc))


if __name__ == "__main__":
    unittest.main()
