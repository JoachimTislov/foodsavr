#!/usr/bin/env python3
import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def load_module():
    spec = importlib.util.spec_from_file_location("sync_labels", ROOT / "scripts/github/sync_labels.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class LabelRulesTest(unittest.TestCase):
    def setUp(self):
        self.module = load_module()
        self.config = json.loads((ROOT / ".agents/github/labels.json").read_text())

    def test_bug_pr_gets_type_area_risk_and_ci_labels(self):
        labels = self.module.classify(
            {"number": 1, "title": "Fix auth regression", "body": "", "draft": False, "is_pull_request": True},
            [".github/workflows/agent-system.yml", "lib/auth.dart"],
            [{"status": "completed", "conclusion": "success"}],
            [],
            self.config,
        )
        self.assertTrue({"type/bug", "area/ci", "risk/security"} <= labels)
        self.assertNotIn("area/app", labels)
        self.assertFalse(any(label.startswith("status/") for label in labels))

    def test_issue_defaults_to_task_and_preserves_human_labels_in_sync_diff(self):
        labels = self.module.classify(
            {"number": 2, "title": "Investigate startup", "body": "", "state": "open", "is_pull_request": False},
            [], [], [], self.config,
        )
        current = {"help wanted", "bug"}
        self.assertIn("type/task", labels)
        self.assertEqual(self.module.is_managed("help wanted", self.config["managed_prefixes"]), False)
        self.assertIn("bug", current - labels)


if __name__ == "__main__":
    unittest.main()
