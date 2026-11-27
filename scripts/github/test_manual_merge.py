#!/usr/bin/env python3
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

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
    base = dict(number=7, state="OPEN", draft=False, base="develop", branch="feat/x", head=HEAD, author="owner",
                author_association="OWNER",
                merge_state="CLEAN", fork=False, contexts=contexts, review_decision="APPROVED",
                reviews=[{
                    "state": "COMMENTED", "body": f'<!-- agent-review: {{"pr": 7, "head_sha": "{HEAD}", '
                    f'"tier": "fast", "status": "approved"}} -->',
                    "author": {"login": "github-actions[bot]", "__typename": "Bot"},
                    "commit": {"oid": HEAD},
                }])
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

    def test_only_a_commit_status_satisfies_validation(self):
        checks = green()[:2] + [run("Validation result", conclusion="SKIPPED")]
        self.assertEqual(mm.decide(pr(checks), []).states["Validation result"], "missing")
        self.assertTrue(mm.decide(pr(checks + [status("Validation result", "SUCCESS")]), []).ok)

    def test_skipped_required_check_passes(self):
        contexts = green() + [run("Web smoke test", conclusion="SKIPPED", workflow="Validation")]
        self.assertTrue(mm.decide(pr(contexts), ["Web smoke test"]).ok)

    def test_review_tier_block_requires_explicit_override(self):
        # Manual merge preserves the review safeguard unless the caller explicitly
        # authorizes the bypass.
        contexts = green() + [run("Adaptive PR review", conclusion="FAILURE", workflow="Agent review")]
        candidate = pr(contexts, reviews=[], review_decision=None)
        verdict = mm.decide(candidate, [])
        self.assertFalse(verdict.ok)
        self.assertTrue(any("review not approved" in b for b in verdict.blockers))
        override = mm.decide(candidate, [], override_review=True)
        self.assertTrue(override.ok, override.blockers)
        self.assertTrue(any("explicit authorized review override" in n for n in override.notes))

    def test_security_pr_requires_explicit_override(self):
        candidate = pr(green(), labels={"risk/security"})
        self.assertFalse(mm.decide(candidate, []).ok)
        self.assertTrue(mm.decide(candidate, [], override_review=True).ok)

    def test_open_threads_require_explicit_override(self):
        candidate = pr(green(), open_threads=1)
        verdict = mm.decide(candidate, [])
        self.assertFalse(verdict.ok)
        self.assertIn("unresolved review thread", " ".join(verdict.blockers))
        self.assertTrue(mm.decide(candidate, [], override_review=True).ok)

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
        parsed = mm.from_node(node, green())
        self.assertEqual(parsed.head, HEAD)
        self.assertTrue(mm.decide(parsed, [], override_review=True).ok)

    def test_no_rollup_means_nothing_reported(self):
        node = {"number": 3, "state": "OPEN", "isDraft": False, "baseRefName": "develop", "headRefOid": HEAD,
                "mergeStateStatus": "CLEAN", "isCrossRepository": False, "commits": {"nodes": [{"commit": {}}]}}
        self.assertFalse(mm.decide(mm.from_node(node, []), []).ok)

    def test_pages_through_contexts_on_the_same_head(self):
        def response(**repo):
            return json.dumps({"data": {"repository": repo}})

        def page(checks, cursor=None):
            return response(object={"statusCheckRollup": {"contexts": {
                "nodes": checks, "pageInfo": {"hasNextPage": cursor is not None, "endCursor": cursor},
            }}})

        node = {"number": 3, "state": "OPEN", "baseRefName": "develop",
                "headRefOid": HEAD, "mergeStateStatus": "CLEAN"}
        with patch.object(mm, "gh", side_effect=[response(pullRequest=node), page(green()[:2], "next"),
                                                 page(green()[2:])]) as gh:
            parsed = mm.fetch_pr("owner/repo", 3)
        self.assertEqual(parsed.head, HEAD)
        self.assertTrue(mm.decide(parsed, [], override_review=True).ok)
        first, second = [call.args for call in gh.call_args_list[1:]]
        self.assertIn(f"head={HEAD}", first)
        self.assertEqual(second, (*first, "-f", "cursor=next"))


if __name__ == "__main__":
    unittest.main()
