#!/usr/bin/env python3
"""Unit tests for check_healing_patch two-way-door path guardrails."""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.monitoring.check_healing_patch import paths_from_patch_text, validate_paths  # noqa: E402


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
            ".github/workflows/agent-implement.yml",
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


if __name__ == "__main__":
    unittest.main()
