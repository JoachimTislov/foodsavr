#!/usr/bin/env python3
"""Unit tests for scripts/ci/head_jobs.py."""

from __future__ import annotations

import importlib.util
import io
import json
import subprocess
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("head_jobs", ROOT / "scripts/ci/head_jobs.py")
head_jobs = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["head_jobs"] = head_jobs
spec.loader.exec_module(head_jobs)


def fake_gh(runs: list[int], jobs: dict[int, list[tuple[str, str]]]):
    def run(argv, **_kwargs):
        if argv[1:3] == ["run", "list"]:
            assert "--commit" in argv and "--status" in argv and argv[argv.index("--status") + 1] == "completed"
            out = json.dumps([{"databaseId": r} for r in runs])
        else:
            run_id = int(argv[2].split("/")[5])  # repos/<o>/<r>/actions/runs/<id>/jobs
            out = json.dumps({"jobs": [{"name": n, "conclusion": c} for n, c in jobs.get(run_id, [])]})
        return subprocess.CompletedProcess(argv, 0, out, "")
    return run


class HeadJobsTest(unittest.TestCase):
    def test_lists_successful_jobs_of_other_runs_only(self):
        jobs = {
            11: [("Check & Test", "success"), ("Build documentation", "failure"), ("Decide whether to run CI", "success")],
            12: [("Agent system validation", "success"), ("Check & Test", "skipped")],
            13: [("Web smoke test", "success")],
        }
        with patch.object(head_jobs.subprocess, "run", side_effect=fake_gh([11, 12, 13], jobs)):
            names = head_jobs.passed_jobs("o/r", "pull-request.yml", "abc", exclude_run="13")
        self.assertEqual(names, ["Agent system validation", "Check & Test", "Decide whether to run CI"])

    def test_api_failure_reuses_nothing(self):
        def fail(argv, **_kwargs):
            raise subprocess.CalledProcessError(1, argv)
        stdout = io.StringIO()
        with patch.dict(head_jobs.os.environ, {"GITHUB_REPOSITORY": "o/r"}), \
                patch.object(head_jobs.subprocess, "run", side_effect=fail), redirect_stdout(stdout):
            self.assertEqual(head_jobs.main(["--workflow", "pull-request.yml", "--sha", "abc"]), 0)
        self.assertEqual(stdout.getvalue(), "")


if __name__ == "__main__":
    unittest.main()
