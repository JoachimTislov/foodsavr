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
        d = promote.decide_promotion("abcdef1", "abcdef1", True, [], source_branch="develop", target_branch="nightly")
        self.assertEqual(d.action, "noop")
        self.assertIn("nightly", d.detail)

    def test_blocks_non_fast_forward(self):
        d = promote.decide_promotion(
            "abcdef1",
            "1234567",
            False,
            [check_run("Detect changed areas")],
            source_branch="beta",
            target_branch="stable",
        )
        self.assertEqual(d.action, "blocked")
        self.assertIn("stable", d.detail)
        self.assertIn("beta", d.detail)

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
            source_branch="nightly",
            target_branch="beta",
        )
        self.assertEqual(d.action, "promote")

    def test_develop_promotes_without_duplicate_develop_push_checks_but_blocks_failures(self):
        d_ok = promote.decide_promotion("abcdef1", "1234567", True, [], source_branch="develop", target_branch="nightly")
        self.assertEqual(d_ok.action, "promote")
        d_fail = promote.decide_promotion(
            "abcdef1",
            "1234567",
            True,
            [check_run("Check & Test", conclusion="FAILURE")],
            source_branch="develop",
            target_branch="nightly",
        )
        self.assertEqual(d_fail.action, "blocked")
        d_missing_on_channel = promote.decide_promotion(
            "abcdef1", "1234567", True, [], source_branch="nightly", target_branch="beta"
        )
        self.assertEqual(d_missing_on_channel.action, "pending")
        d_direct_release_missing = promote.decide_promotion(
            "abcdef1", "1234567", True, [], source_branch="develop", target_branch="release"
        )
        self.assertEqual(d_direct_release_missing.action, "pending")
        d_spoofed_app = promote.decide_promotion(
            "abcdef1",
            "1234567",
            True,
            [{"__typename": "CheckRun", "name": "Detect changed areas", "status": "COMPLETED", "conclusion": "SUCCESS",
              "checkSuite": {"app": {"slug": "spoofed-app"}}}],
            source_branch="nightly",
            target_branch="beta",
        )
        self.assertEqual(d_spoofed_app.action, "pending")


class ResolveStepsTest(unittest.TestCase):
    def test_schedule_resolution(self):
        self.assertEqual(promote.resolve_steps(schedule="0 4 * * *"), [("develop", "nightly")])
        self.assertEqual(promote.resolve_steps(schedule="0 5 * * 1"), [("nightly", "beta")])
        self.assertEqual(
            promote.resolve_steps(schedule="0 6 1,15 * *"),
            [("beta", "stable"), ("stable", "release")],
        )

    def test_manual_channel_resolution(self):
        self.assertEqual(promote.resolve_steps(target_branch="nightly"), [("develop", "nightly")])
        self.assertEqual(promote.resolve_steps(target_branch="beta", source_branch="default"), [("nightly", "beta")])
        self.assertEqual(promote.resolve_steps(target_branch="stable"), [("beta", "stable")])
        self.assertEqual(promote.resolve_steps(target_branch="release"), [("stable", "release")])
        self.assertEqual(
            promote.resolve_steps(target_branch="release", source_branch="develop"),
            [("develop", "release")],
        )

    def test_invalid_inputs_rejected(self):
        with self.assertRaises(ValueError):
            promote.resolve_steps(schedule="0 0 * * *")
        with self.assertRaises(ValueError):
            promote.resolve_steps(target_branch="main")
        with self.assertRaises(ValueError):
            promote.resolve_steps(target_branch="stable", source_branch="stable")
        with self.assertRaises(ValueError):
            promote.resolve_steps(target_branch="nightly", topology="two-stage")
        with self.assertRaises(ValueError):
            promote.resolve_steps(topology="unknown")

    def test_single_and_two_stage_topologies(self):
        self.assertEqual(promote.resolve_steps(schedule="0 4 * * *", topology="single"), [])
        self.assertEqual(promote.resolve_steps(target_branch="release", topology="single"), [])
        self.assertEqual(promote.resolve_steps(schedule="0 4 * * *", topology="two-stage"), [])
        self.assertEqual(promote.resolve_steps(schedule="0 5 * * 1", topology="two-stage"), [])
        self.assertEqual(
            promote.resolve_steps(schedule="0 6 1,15 * *", topology="two-stage"),
            [("develop", "release")],
        )
        self.assertEqual(
            promote.resolve_steps(target_branch="release", topology="two-stage"),
            [("develop", "release")],
        )

    def test_single_topology_main_is_clean_noop_without_token(self):
        code = promote.main(["--repo", "alice/foodsavr", "--topology", "single", "--schedule", "0 4 * * *", "--apply"])
        self.assertEqual(code, 0)


class ChainedPromotionTest(unittest.TestCase):
    def test_biweekly_schedule_chains_stable_into_release(self):
        refs = {
            "origin/beta": "bbbbbbb000000000000000000000000000000000",
            "origin/stable": "aaaaaaa000000000000000000000000000000000",
            "origin/release": "aaaaaaa000000000000000000000000000000000",
        }
        pushed: list[tuple[str, str, str]] = []

        def fake_git(*args):
            self.assertEqual(args[0], "rev-parse")
            return refs[args[1]]

        def fake_push(repo, sha, branch, token):
            pushed.append((repo, sha, branch))

        with patch.object(promote, "git", side_effect=fake_git), \
                patch.object(promote, "remote_branches", return_value={"beta", "stable", "release"}), \
                patch.object(promote, "fetch_branches"), \
                patch.object(promote, "is_ancestor", return_value=True), \
                patch.object(promote, "fetch_commit_contexts", return_value=[check_run("Detect changed areas")]) as fetch, \
                patch.object(promote, "fast_forward_branch", side_effect=fake_push), \
                patch.dict(os.environ, {"GH_TOKEN": "test-token"}, clear=False):
            code = promote.main(["--repo", "JoachimTislov/foodsavr", "--schedule", "0 6 1,15 * *", "--apply"])

        self.assertEqual(code, 0)
        self.assertEqual(fetch.call_count, 1)
        self.assertEqual(
            pushed,
            [
                ("JoachimTislov/foodsavr", refs["origin/beta"], "stable"),
                ("JoachimTislov/foodsavr", refs["origin/beta"], "release"),
            ],
        )


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

    def test_daily_schedule_with_release_missing_promotes_nightly(self):
        self.push_branch("nightly", self.old)
        code, out, pushed = self.run_main("--schedule", "0 4 * * *", "--apply")
        self.assertEqual(code, 0)
        self.assertEqual(pushed, [("nightly", self.new)])
        self.assertNotIn("missing", out)

    def test_biweekly_schedule_with_release_missing_promotes_stable_and_reports_release(self):
        self.push_branch("beta", self.new)
        self.push_branch("stable", self.old)
        code, out, pushed = self.run_main("--schedule", "0 6 1,15 * *", "--apply")
        self.assertEqual(code, 0)
        self.assertEqual(pushed, [("stable", self.new)])
        self.assertIn("stable -> release: missing", out)
        self.assertIn("::warning::", out)
        self.assertIn("owner action", out)

    def test_biweekly_schedule_skips_dependent_step_when_source_missing(self):
        self.push_branch("stable", self.old)
        self.push_branch("release", self.old)
        code, out, pushed = self.run_main("--schedule", "0 6 1,15 * *", "--apply")
        self.assertEqual(code, 0)
        self.assertEqual(pushed, [])
        self.assertIn("beta -> stable: missing", out)
        self.assertIn("stable -> release: skipped", out)

    def test_manual_target_release_missing_fails(self):
        self.push_branch("stable", self.new)
        code, out, pushed = self.run_main("--target-branch", "release", "--apply")
        self.assertEqual(code, 1)
        self.assertEqual(pushed, [])
        self.assertIn("::error::", out)
        self.assertIn("'release'", out)

    def test_existing_branches_promote_chain_and_dry_run_does_not_push(self):
        self.push_branch("beta", self.new)
        self.push_branch("stable", self.old)
        self.push_branch("release", self.old)
        code, out, pushed = self.run_main("--schedule", "0 6 1,15 * *", "--apply")
        self.assertEqual(code, 0)
        self.assertEqual(pushed, [("stable", self.new), ("release", self.new)])
        code, out, pushed = self.run_main("--schedule", "0 6 1,15 * *")
        self.assertEqual(code, 0)
        self.assertEqual(pushed, [])
        self.assertIn("stable -> release: promote", out)

    def test_existing_branch_not_ancestor_still_blocks(self):
        run_git(self.work, "checkout", "-q", "--orphan", "other")
        run_git(self.work, "commit", "-q", "--allow-empty", "-m", "x")
        other = run_git(self.work, "rev-parse", "HEAD")
        self.push_branch("nightly", other)
        code, out, pushed = self.run_main("--schedule", "0 4 * * *", "--apply")
        self.assertEqual(code, 1)
        self.assertEqual(pushed, [])
        self.assertIn("blocked", out)


if __name__ == "__main__":
    unittest.main()
