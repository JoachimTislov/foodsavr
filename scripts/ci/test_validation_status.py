#!/usr/bin/env python3
import importlib.util
import io
import json
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/ci/validation_status.py"


def load_module():
    spec = importlib.util.spec_from_file_location("validation_status", SCRIPT)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    sys.modules["validation_status"] = mod
    spec.loader.exec_module(mod)
    return mod


def needs(**results):
    return json.dumps({k: {"result": v} for k, v in results.items()})


class ValidationStatusTest(unittest.TestCase):
    def setUp(self):
        self.mod = load_module()

    def test_unlabeled_pr_is_pending(self):
        for action in ("opened", "synchronize", "reopened"):
            self.assertEqual(
                self.mod.decide_hold(action=action, label=""),
                ("pending", "Add merge/auto to run Validation"),
            )

    def test_other_label_event_posts_nothing(self):
        self.assertIsNone(self.mod.decide_hold(action="labeled", label="bug"))

    def test_start_is_pending(self):
        self.assertEqual(
            self.mod.decide_start(), ("pending", "Validation running")
        )

    def test_all_green_is_success(self):
        results = self.mod.parse_results(
            needs(changes="success", **{"web-smoke": "success"},
                  **{"android-smoke": "success"}, **{"firestore-rules": "success"})
        )
        self.assertEqual(self.mod.decide_final(results)[0], "success")

    def test_one_failure_is_failure(self):
        results = self.mod.parse_results(
            needs(changes="success", **{"web-smoke": "failure"},
                  **{"android-smoke": "success"})
        )
        self.assertEqual(self.mod.decide_final(results)[0], "failure")

    def test_path_skipped_jobs_are_success(self):
        results = self.mod.parse_results(
            needs(changes="success", **{"web-smoke": "skipped"},
                  **{"android-smoke": "skipped"}, **{"firestore-rules": "skipped"})
        )
        self.assertEqual(self.mod.decide_final(results)[0], "success")

    def test_skipped_or_failed_gate_is_failure(self):
        for gate in ("skipped", "failure"):
            results = self.mod.parse_results(
                needs(changes=gate, **{"web-smoke": "skipped"})
            )
            self.assertEqual(self.mod.decide_final(results)[0], "failure")

    def test_start_job_outcome_is_ignored(self):
        results = self.mod.parse_results(
            needs(**{"validation-start": "failure"}, changes="success",
                  **{"web-smoke": "skipped"})
        )
        self.assertEqual(self.mod.decide_final(results)[0], "success")

    def test_cancelled_posts_nothing(self):
        results = self.mod.parse_results(
            needs(changes="success", **{"web-smoke": "cancelled"})
        )
        self.assertIsNone(self.mod.decide_final(results))

    def test_cli_posts_final_status(self):
        env = {
            "NEEDS_JSON": needs(changes="success", **{"web-smoke": "success"}),
            "GITHUB_REPOSITORY": "o/r",
            "TARGET_SHA": "abc",
            "RUN_URL": "https://example.test/run",
        }
        with patch.dict("os.environ", env, clear=True), patch.object(
            self.mod, "post_status"
        ) as post, redirect_stdout(io.StringIO()):
            self.assertEqual(self.mod.main(["final"]), 0)
        post.assert_called_once_with(
            "o/r", "abc", "success", "Validation passed", "https://example.test/run"
        )

    def test_cli_cancelled_does_not_post(self):
        env = {"NEEDS_JSON": needs(changes="cancelled")}
        with patch.dict("os.environ", env, clear=True), patch.object(
            self.mod, "post_status"
        ) as post, redirect_stdout(io.StringIO()):
            self.assertEqual(self.mod.main(["final"]), 0)
        post.assert_not_called()

    def test_cli_fork_skips_with_notice(self):
        env = {"IS_FORK": "true", "PR_ACTION": "opened"}
        out = io.StringIO()
        with patch.dict("os.environ", env, clear=True), patch.object(
            self.mod, "post_status"
        ) as post, redirect_stdout(out):
            self.assertEqual(self.mod.main(["hold"]), 0)
        post.assert_not_called()
        self.assertIn("::notice::", out.getvalue())

    def test_cli_foreign_label_does_not_post(self):
        env = {"PR_ACTION": "labeled", "PR_LABEL": "bug"}
        with patch.dict("os.environ", env, clear=True), patch.object(
            self.mod, "post_status"
        ) as post, redirect_stdout(io.StringIO()):
            self.assertEqual(self.mod.main(["hold"]), 0)
        post.assert_not_called()


if __name__ == "__main__":
    unittest.main()
