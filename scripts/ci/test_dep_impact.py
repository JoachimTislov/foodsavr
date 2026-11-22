#!/usr/bin/env python3
import importlib.util
import io
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/ci/dep_impact.py"


def load_module():
    spec = importlib.util.spec_from_file_location("dep_impact", SCRIPT)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    sys.modules["dep_impact"] = mod
    spec.loader.exec_module(mod)
    return mod


class DepImpactTest(unittest.TestCase):
    def test_non_pull_request_runs_everything(self):
        mod = load_module()
        self.assertEqual(
            mod.classify_impact(event_name="push", pr_author="", diff_text=""),
            (True, True),
        )

    def test_non_dependabot_pr_runs_everything(self):
        mod = load_module()
        self.assertEqual(
            mod.classify_impact(
                event_name="pull_request",
                pr_author="JoachimTislov",
                diff_text="+  flutter_lints: ^6.0.1\n",
            ),
            (True, True),
        )

    def test_dependabot_pure_dart_skips_android_and_web(self):
        mod = load_module()
        diff = (
            "--- a/pubspec.yaml\n"
            "+++ b/pubspec.yaml\n"
            "@@ -77 +77 @@\n"
            "-  flutter_lints: ^5.0.0\n"
            "+  flutter_lints: ^6.0.0\n"
        )
        self.assertEqual(
            mod.classify_impact(
                event_name="pull_request",
                pr_author="dependabot[bot]",
                diff_text=diff,
            ),
            (False, False),
        )

    def test_dependabot_android_only_runs_only_android(self):
        mod = load_module()
        diff = (
            "-  google_mlkit_barcode_scanning: ^0.14.1\n"
            "+  google_mlkit_barcode_scanning: ^0.14.2\n"
        )
        self.assertEqual(
            mod.classify_impact(
                event_name="pull_request",
                pr_author="dependabot[bot]",
                diff_text=diff,
            ),
            (True, False),
        )

    def test_dependabot_web_only_runs_only_web(self):
        mod = load_module()
        diff = "-  web: ^1.1.0\n+  web: ^1.1.1\n"
        self.assertEqual(
            mod.classify_impact(
                event_name="pull_request",
                pr_author="dependabot[bot]",
                diff_text=diff,
            ),
            (False, True),
        )

    def test_dependabot_cross_platform_runs_both(self):
        mod = load_module()
        diff = (
            "-  firebase_auth: ^6.7.0\n"
            "+  firebase_auth: ^6.7.1\n"
        )
        self.assertEqual(
            mod.classify_impact(
                event_name="pull_request",
                pr_author="dependabot[bot]",
                diff_text=diff,
            ),
            (True, True),
        )

    def test_dependabot_empty_diff_or_sdk_only_runs_everything(self):
        mod = load_module()
        diff = "-  sdk: ^3.10.6\n+  sdk: ^3.10.7\n"
        self.assertEqual(
            mod.classify_impact(
                event_name="pull_request",
                pr_author="dependabot[bot]",
                diff_text=diff,
            ),
            (True, True),
        )

    def test_main_writes_github_output(self):
        mod = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            out_file = Path(tmp) / "github_output.txt"
            diff = "-  mocktail: ^1.0.3\n+  mocktail: ^1.0.4\n"
            with patch.dict(
                os.environ,
                {
                    "GITHUB_EVENT_NAME": "pull_request",
                    "PR_AUTHOR": "dependabot[bot]",
                    "GITHUB_OUTPUT": str(out_file),
                },
                clear=False,
            ), patch.object(mod, "git_pubspec_diff", return_value=diff):
                stdout = io.StringIO()
                with redirect_stdout(stdout):
                    rc = mod.main(["--base", "origin/main"])
            self.assertEqual(rc, 0)
            self.assertEqual(
                out_file.read_text(encoding="utf-8").splitlines(),
                ["run_android=false", "run_web=false"],
            )


if __name__ == "__main__":
    unittest.main()
