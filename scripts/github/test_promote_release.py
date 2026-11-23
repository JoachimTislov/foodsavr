#!/usr/bin/env python3
import contextlib
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("promote_release", ROOT / "scripts/github/promote_release.py")
promote = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["promote_release"] = promote
spec.loader.exec_module(promote)


def check_run(name, status="COMPLETED", conclusion="SUCCESS", workflow=None):
    node = {"__typename": "CheckRun", "name": name, "status": status, "conclusion": conclusion}
    if workflow is not None:
        node["checkSuite"] = {"workflowRun": {"workflow": {"name": workflow}}}
    return node


class PromoteDecisionTest(unittest.TestCase):
    def test_noop_when_shas_match(self):
        d = promote.decide_promotion("abcdef1", "abcdef1", True, [], source_branch="develop", target_branch="daily")
        self.assertEqual(d.action, "noop")
        self.assertIn("daily", d.detail)

    def test_blocks_non_fast_forward(self):
        d = promote.decide_promotion(
            "abcdef1",
            "1234567",
            False,
            [check_run("Detect changed areas")],
            source_branch="weekly",
            target_branch="stable",
        )
        self.assertEqual(d.action, "blocked")
        self.assertIn("stable", d.detail)
        self.assertIn("weekly", d.detail)

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
                check_run("Fast-forward release channel", status="IN_PROGRESS", conclusion=None, workflow="Promote release channels"),
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
            source_branch="daily",
            target_branch="weekly",
        )
        self.assertEqual(d.action, "promote")

    def test_effective_run_evaluation_leaves_single_runs_unchanged(self):
        def run(name, conclusion="SUCCESS"):
            node = check_run(name, conclusion=conclusion, workflow="Validation")
            node["startedAt"] = "2026-11-21T12:00:00Z"
            node["checkSuite"]["workflowRun"]["databaseId"] = 100
            return node

        self.assertIn("databaseId", promote.COMMIT_ROLLUP_QUERY)
        self.assertIn("startedAt", promote.COMMIT_ROLLUP_QUERY)
        ok = promote.decide_promotion(
            "abcdef1", "1234567", True, [run("Detect changed areas"), run("Check & Test")],
            source_branch="daily", target_branch="weekly",
        )
        self.assertEqual(ok.action, "promote")
        failed = promote.decide_promotion(
            "abcdef1", "1234567", True, [run("Detect changed areas"), run("Check & Test", "CANCELLED")],
            source_branch="daily", target_branch="weekly",
        )
        self.assertEqual(failed.action, "blocked")

    def test_develop_promotes_without_duplicate_develop_push_checks_but_blocks_failures(self):
        d_ok = promote.decide_promotion("abcdef1", "1234567", True, [], source_branch="develop", target_branch="daily")
        self.assertEqual(d_ok.action, "promote")
        d_fail = promote.decide_promotion(
            "abcdef1",
            "1234567",
            True,
            [check_run("Check & Test", conclusion="FAILURE")],
            source_branch="develop",
            target_branch="daily",
        )
        self.assertEqual(d_fail.action, "blocked")
        d_missing_on_channel = promote.decide_promotion(
            "abcdef1", "1234567", True, [], source_branch="daily", target_branch="weekly"
        )
        self.assertEqual(d_missing_on_channel.action, "pending")
        d_direct_stable_missing = promote.decide_promotion(
            "abcdef1", "1234567", True, [], source_branch="develop", target_branch="stable"
        )
        self.assertEqual(d_direct_stable_missing.action, "pending")
        d_spoofed_app = promote.decide_promotion(
            "abcdef1",
            "1234567",
            True,
            [{"__typename": "CheckRun", "name": "Detect changed areas", "status": "COMPLETED", "conclusion": "SUCCESS",
              "checkSuite": {"app": {"slug": "spoofed-app"}}}],
            source_branch="daily",
            target_branch="weekly",
        )
        self.assertEqual(d_spoofed_app.action, "pending")


class ResolveStepsTest(unittest.TestCase):
    def test_schedule_resolution(self):
        self.assertEqual(promote.resolve_steps(schedule="0 4 * * *"), [("develop", "daily")])
        self.assertEqual(promote.resolve_steps(schedule="0 5 * * 1"), [("daily", "weekly")])
        self.assertEqual(
            promote.resolve_steps(schedule="0 6 1,15 * *"),
            [("weekly", "stable")],
        )

    def test_manual_channel_resolution(self):
        self.assertEqual(promote.resolve_steps(target_branch="daily"), [("develop", "daily")])
        self.assertEqual(promote.resolve_steps(target_branch="weekly", source_branch="default"), [("daily", "weekly")])
        self.assertEqual(promote.resolve_steps(target_branch="stable"), [("weekly", "stable")])
        self.assertEqual(
            promote.resolve_steps(target_branch="stable", source_branch="develop"),
            [("develop", "stable")],
        )

    def test_invalid_inputs_rejected(self):
        with self.assertRaises(ValueError):
            promote.resolve_steps(schedule="0 0 * * *")
        with self.assertRaises(ValueError):
            promote.resolve_steps(target_branch="main")
        with self.assertRaises(ValueError):
            promote.resolve_steps(target_branch="stable", source_branch="stable")
        with self.assertRaises(ValueError):
            promote.resolve_steps(target_branch="daily", topology="two-stage")
        with self.assertRaises(ValueError):
            promote.resolve_steps(topology="unknown")

    def test_single_and_two_stage_topologies(self):
        self.assertEqual(promote.resolve_steps(schedule="0 4 * * *", topology="single"), [])
        self.assertEqual(promote.resolve_steps(target_branch="stable", topology="single"), [])
        self.assertEqual(promote.resolve_steps(schedule="0 4 * * *", topology="two-stage"), [])
        self.assertEqual(promote.resolve_steps(schedule="0 5 * * 1", topology="two-stage"), [])
        self.assertEqual(
            promote.resolve_steps(schedule="0 6 1,15 * *", topology="two-stage"),
            [("develop", "stable")],
        )
        self.assertEqual(
            promote.resolve_steps(target_branch="stable", topology="two-stage"),
            [("develop", "stable")],
        )

    def test_single_topology_main_is_clean_noop_without_token(self):
        code = promote.main(["--repo", "alice/foodsavr", "--topology", "single", "--schedule", "0 4 * * *", "--apply"])
        self.assertEqual(code, 0)


def run_git(cwd, *args):
    return subprocess.run(
        ["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *args],
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


class MainWithRemoteTest(unittest.TestCase):
    """Exercise main() against a temporary bare remote and a clone (no network)."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = Path(self._tmp.name)
        self.remote = root / "remote.git"
        self.work = root / "work"
        run_git(root, "init", "--bare", "-b", "develop", str(self.remote))
        run_git(root, "clone", str(self.remote), str(self.work))
        run_git(self.work, "checkout", "-b", "develop")
        (self.work / "f").write_text("1")
        run_git(self.work, "add", "f")
        run_git(self.work, "commit", "-m", "one")
        self.old = run_git(self.work, "rev-parse", "HEAD")
        (self.work / "f").write_text("2")
        run_git(self.work, "commit", "-am", "two")
        self.new = run_git(self.work, "rev-parse", "HEAD")
        run_git(self.work, "push", "origin", "develop")

    def push_branch(self, name, sha):
        run_git(self.work, "push", "origin", f"{sha}:refs/heads/{name}")

    def run_main(self, *argv, topology="full-channels"):
        out = io.StringIO()
        pushed: list[tuple[str, str]] = []
        cwd = os.getcwd()
        os.chdir(self.work)
        try:
            with patch.object(promote, "fetch_commit_contexts", return_value=[check_run("Detect changed areas")]), \
                    patch.object(promote, "fast_forward_branch", side_effect=lambda r, sha, b, t: pushed.append((b, sha))), \
                    patch.dict(os.environ, {"GH_TOKEN": "t", "GITHUB_STEP_SUMMARY": ""}, clear=False), \
                    contextlib.redirect_stdout(out):
                code = promote.main(["--repo", "o/r", "--topology", topology, *argv])
        finally:
            os.chdir(cwd)
        return code, out.getvalue(), pushed

    def test_daily_schedule_only_needs_develop_and_daily(self):
        self.push_branch("daily", self.old)
        self.push_branch("nightly", self.old)
        code, out, pushed = self.run_main("--schedule", "0 4 * * *", "--apply")
        self.assertEqual(code, 0)
        self.assertEqual(pushed, [("daily", self.new)])
        self.assertNotIn("missing", out)

    def test_biweekly_schedule_promotes_stable_only(self):
        self.push_branch("weekly", self.new)
        self.push_branch("stable", self.old)
        code, out, pushed = self.run_main("--schedule", "0 6 1,15 * *", "--apply")
        self.assertEqual(code, 0)
        self.assertEqual(pushed, [("stable", self.new)])

    def test_schedule_skips_missing_source(self):
        self.push_branch("stable", self.old)
        code, out, pushed = self.run_main("--schedule", "0 6 1,15 * *", "--apply")
        self.assertEqual(code, 0)
        self.assertEqual(pushed, [])
        self.assertIn("weekly -> stable: missing", out)

    def test_manual_target_stable_missing_fails(self):
        self.push_branch("weekly", self.new)
        code, out, pushed = self.run_main("--target-branch", "stable", "--apply")
        self.assertEqual(code, 1)
        self.assertEqual(pushed, [])
        self.assertIn("::error::", out)
        self.assertIn("'stable'", out)

    def test_dry_run_does_not_push_and_ahead_target_is_noop(self):
        self.push_branch("daily", self.old)
        code, out, pushed = self.run_main("--schedule", "0 4 * * *")
        self.assertEqual((code, pushed), (0, []))
        self.assertIn("develop -> daily: promote", out)

        self.push_branch("weekly", self.new)
        code, out, pushed = self.run_main("--schedule", "0 5 * * 1", "--apply")
        self.assertEqual((code, pushed), (0, []))
        self.assertIn("is ahead", out)

    def test_existing_branch_not_ancestor_still_blocks(self):
        run_git(self.work, "checkout", "-q", "--orphan", "other")
        run_git(self.work, "commit", "-q", "--allow-empty", "-m", "x")
        other = run_git(self.work, "rev-parse", "HEAD")
        self.push_branch("daily", other)
        code, out, pushed = self.run_main("--schedule", "0 4 * * *", "--apply")
        self.assertEqual(code, 1)
        self.assertEqual(pushed, [])
        self.assertIn("blocked", out)


if __name__ == "__main__":
    unittest.main()
