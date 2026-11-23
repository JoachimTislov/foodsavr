#!/usr/bin/env python3
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import manual_merge as mm  # noqa: E402

HEAD = "a" * 40


def run(name, conclusion="SUCCESS", status="COMPLETED", workflow="CI", started="2026-11-23T10:00:00Z"):
    return {
        "__typename": "CheckRun", "name": name, "status": status, "conclusion": conclusion,
        "startedAt": started, "checkSuite": {"app": {"slug": "github-actions"},
                                              "workflowRun": {"databaseId": 1, "workflow": {"name": workflow}}},
    }


def status(context, state):
    return {"__typename": "StatusContext", "context": context, "state": state}


def green():
    return [run("Decide whether to run CI"), run("Check & Test"), status("Validation result", "SUCCESS")]


def pr(contexts, **kw):
    base = dict(number=7, state="OPEN", draft=False, base="develop", branch="feat/x", head=HEAD,
                merge_state="CLEAN", fork=False, contexts=contexts)
    base.update(kw)
    return mm.PullRequest(**base)


class DecideTest(unittest.TestCase):
    def test_green_merges(self):
        verdict = mm.decide(pr(green()), [])
        self.assertTrue(verdict.ok, verdict.blockers)
        self.assertEqual(verdict.head, HEAD)

    def test_red_required_check_refuses(self):
        contexts = [run("Decide whether to run CI"), run("Check & Test", conclusion="FAILURE"),
                    status("Validation result", "SUCCESS")]
        verdict = mm.decide(pr(contexts), [])
        self.assertFalse(verdict.ok)
        self.assertIn("required check failed: Check & Test", verdict.blockers)

    def test_red_validation_result_refuses(self):
        contexts = green()[:2] + [status("Validation result", "FAILURE")]
        self.assertFalse(mm.decide(pr(contexts), []).ok)

    def test_pending_validation_points_at_make_validate(self):
        contexts = green()[:2] + [status("Validation result", "PENDING")]
        verdict = mm.decide(pr(contexts), [])
        self.assertFalse(verdict.ok)
        self.assertTrue(any("make validate REF=feat/x" in b for b in verdict.blockers))

    def test_pending_check_run_refuses(self):
        contexts = [run("Decide whether to run CI"), run("Check & Test", status="IN_PROGRESS", conclusion=None),
                    status("Validation result", "SUCCESS")]
        verdict = mm.decide(pr(contexts), [])
        self.assertIn("required check pending: Check & Test", verdict.blockers)

    def test_missing_required_check_refuses(self):
        verdict = mm.decide(pr(green()[:2]), [])
        self.assertFalse(verdict.ok)
        self.assertTrue(any("Validation result" in b for b in verdict.blockers))

    def test_ruleset_required_checks_are_added(self):
        verdict = mm.decide(pr(green()), ["Web smoke test"])
        self.assertIn("required check never reported: Web smoke test", verdict.blockers)

    def test_skipped_required_check_passes(self):
        contexts = green() + [run("Web smoke test", conclusion="SKIPPED", workflow="Validation")]
        self.assertTrue(mm.decide(pr(contexts), ["Web smoke test"]).ok)

    def test_review_tier_only_block_does_not_refuse(self):
        # The merge gate would block on a missing review attestation and a failing
        # Agent review run; neither is a required check, so the bypass merges.
        contexts = green() + [run("Adaptive PR review", conclusion="FAILURE", workflow="Agent review")]
        verdict = mm.decide(pr(contexts), [])
        self.assertTrue(verdict.ok, verdict.blockers)
        self.assertTrue(any("review tier" in n for n in verdict.notes))

    def test_failing_optional_check_is_a_note_not_a_blocker(self):
        contexts = green() + [run("Codecov", conclusion="FAILURE", workflow="CI")]
        verdict = mm.decide(pr(contexts, merge_state="UNSTABLE"), [])
        self.assertTrue(verdict.ok)
        self.assertTrue(any("Codecov" in n for n in verdict.notes))

    def test_structural_blockers(self):
        for kw, text in (
            ({"draft": True}, "draft"),
            ({"state": "MERGED"}, "merged"),
            ({"base": "main"}, "base is main"),
            ({"fork": True}, "fork"),
            ({"merge_state": "DIRTY"}, "conflicts"),
            ({"merge_state": "BEHIND"}, "behind"),
            ({"merge_state": "UNKNOWN"}, "computing"),
            ({"merge_state": "BLOCKED"}, "branch rules"),
        ):
            with self.subTest(kw=kw):
                verdict = mm.decide(pr(green(), **kw), [])
                self.assertFalse(verdict.ok)
                self.assertTrue(any(text in b for b in verdict.blockers), verdict.blockers)

    def test_newer_run_supersedes_older_failure(self):
        contexts = [run("Decide whether to run CI"), run("Check & Test", conclusion="FAILURE", started="2026-11-23T09:00:00Z"),
                    run("Check & Test", started="2026-11-23T10:00:00Z"), status("Validation result", "SUCCESS")]
        self.assertTrue(mm.decide(pr(contexts), []).ok)


class FromNodeTest(unittest.TestCase):
    def test_parses_graphql_node(self):
        node = {"number": 3, "state": "OPEN", "isDraft": False, "baseRefName": "develop", "headRefName": "b",
                "headRefOid": HEAD, "mergeStateStatus": "CLEAN", "isCrossRepository": False,
                "commits": {"nodes": [{"commit": {"statusCheckRollup": {"contexts": {"nodes": green()}}}}]}}
        parsed = mm.from_node(node)
        self.assertEqual(parsed.head, HEAD)
        self.assertTrue(mm.decide(parsed, []).ok)

    def test_no_rollup_means_nothing_reported(self):
        node = {"number": 3, "state": "OPEN", "isDraft": False, "baseRefName": "develop", "headRefOid": HEAD,
                "mergeStateStatus": "CLEAN", "isCrossRepository": False, "commits": {"nodes": [{"commit": {}}]}}
        self.assertFalse(mm.decide(mm.from_node(node), []).ok)


if __name__ == "__main__":
    unittest.main()
