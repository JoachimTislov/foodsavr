#!/usr/bin/env python3
"""Unit tests for check_healing_patch two-way-door path guardrails."""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.monitoring.check_healing_patch import (  # noqa: E402
    inspect_patch_text,
    parse_git_raw_diff,
    paths_from_patch_text,
    validate_paths,
)


class CheckHealingPatchTest(unittest.TestCase):
    def test_allows_two_way_door_app_web_and_test_paths(self):
        ok, errors = validate_paths([
            "lib/main.dart",
            "lib/services/error_reporting_service.dart",
            "web/index.html",
            "test/main_test.dart",
            "assets/translations/en.json",
            "packages/foodsavr_core/lib/foo.dart",
            "packages/foodsavr_core/test/foo_test.dart",
        ])
        self.assertTrue(ok)
        self.assertEqual(errors, [])

    def test_rejects_sensitive_and_unallowlisted_paths(self):
        disallowed = [
            ".github/workflows/agent-ops.yml",
            ".agents/policies/agent-implement.json",
            "infra/terraform/main.tf",
            "firestore-rules/firestore.rules",
            "scripts/secrets/rotate.py",
            "pubspec.yaml",
            "../outside.dart",
            "/etc/passwd",
        ]
        for path in disallowed:
            ok, errors = validate_paths(["lib/main.dart", path])
            self.assertFalse(ok, f"Expected {path} to be rejected")
            self.assertTrue(errors)

    def test_rejects_empty_patch_and_parses_diff_headers(self):
        ok, _ = validate_paths([])
        self.assertFalse(ok)
        patch = (
            "diff --git a/lib/main.dart b/lib/main.dart\n"
            "--- a/lib/main.dart\n"
            "+++ b/lib/main.dart\n"
            "diff --git a/.github/workflows/ci.yml b/.github/workflows/ci.yml\n"
        )
        paths = paths_from_patch_text(patch)
        self.assertEqual(paths, [".github/workflows/ci.yml", "lib/main.dart"])
        ok_patch, _ = validate_paths(paths)
        self.assertFalse(ok_patch)

    def test_rejects_symlinks_and_submodules_in_diff_and_git_raw(self):
        symlink_patch = (
            "diff --git a/lib/escape.dart b/lib/escape.dart\n"
            "new file mode 120000\n"
            "index 0000000..1111111\n"
            "--- /dev/null\n"
            "+++ b/lib/escape.dart\n"
            "@@ -0,0 +1 @@\n"
            "+../.github/workflows/ci.yml\n"
        )
        paths, mode_errors = inspect_patch_text(symlink_patch)
        ok, errors = validate_paths(paths, mode_errors=mode_errors)
        self.assertFalse(ok)
        self.assertTrue(any("120000" in err for err in errors))

        raw_submod = ":000000 160000 0000000 2222222 A\tlib/submod\n"
        raw_paths, raw_errors = parse_git_raw_diff(raw_submod)
        ok_raw, all_raw_errors = validate_paths(raw_paths, mode_errors=raw_errors)
        self.assertFalse(ok_raw)
        self.assertTrue(any("160000" in err for err in all_raw_errors))


if __name__ == "__main__":
    unittest.main()
