#!/usr/bin/env python3
import importlib.util
import json
import subprocess
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch
from urllib.parse import unquote


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
            {
                "number": 1,
                "title": "Fix auth regression",
                "is_pull_request": True,
                "labels": [{"name": "area/web"}],
            },
            [".github/workflows/agent-system.yml", "lib/auth.dart"],
            [{"status": "completed", "conclusion": "success"}],
            [],
            self.config,
        )
        self.assertTrue({"type/bug", "area/ci", "risk/security"} <= labels)
        self.assertNotIn("area/app", labels)
        self.assertNotIn("area/web", labels)
        self.assertFalse(any(label.startswith("status/") for label in labels))

    def test_agent_log_files_do_not_count_toward_area_agents(self):
        pull = {"number": 3, "title": "Add recipe screen", "is_pull_request": True, "labels": []}
        logs = [
            ".agents/events/2026/11/20261123T101530123456Z-t3-code-abc-1a2b3c.jsonl",
            ".agents/ledger.jsonl",
            ".agents/sessions/index.jsonl",
        ]
        app = self.module.classify(pull, ["lib/recipes/model.dart", *logs], [], [], self.config)
        self.assertIn("area/app", app)
        self.assertNotIn("area/agents", app)
        self.assertFalse({label for label in self.module.classify(pull, logs, [], [], self.config) if label.startswith("area/")})
        real = self.module.classify(pull, [*logs, ".agents/skills/commit/SKILL.md"], [], [], self.config)
        self.assertIn("area/agents", real)

    def test_issue_keeps_manual_area_and_risk_labels_across_syncs(self):
        expected = {"area/web", "area/agents", "risk/security", "area/ci", "type/task"}
        labels = {"area/web", "area/agents", "risk/security", "ci"}

        def github_api(command, **kwargs):
            endpoint = command[2]
            if endpoint.endswith("/issues/2/labels") and "POST" in command:
                labels.update(json.loads(kwargs["input"])["labels"])
            elif "/issues/2/labels/" in endpoint and "DELETE" in command:
                labels.discard(unquote(endpoint.rsplit("/", 1)[1]))
            return subprocess.CompletedProcess(command, 0, "", "")

        def fetch_issue(repo, endpoint):
            self.assertEqual(endpoint, "issues/2")
            return {
                "number": 2,
                "title": "Investigate startup",
                "labels": [{"name": label} for label in labels],
            }

        with (
            patch.object(self.module, "gh_json", side_effect=fetch_issue),
            patch.object(self.module.subprocess, "run", side_effect=github_api),
            redirect_stdout(StringIO()),
        ):
            for _ in range(2):
                self.assertEqual(
                    self.module.main(["--repo", "owner/repo", "--number", "2", "--apply"]),
                    0,
                )
                self.assertEqual(labels, expected)

    def test_apply_keeps_a_label_added_after_the_snapshot(self):
        # merge/auto lands between the read and the write; the sync must not drop it.
        labels = {"type/bug"}
        commands = []

        def github_api(command, **kwargs):
            commands.append(command)
            endpoint = command[2]
            if endpoint.endswith("/issues/7/labels") and "POST" in command:
                labels.update(json.loads(kwargs["input"])["labels"])
            elif "/issues/7/labels/" in endpoint and "DELETE" in command:
                labels.discard(unquote(endpoint.rsplit("/", 1)[1]))
            return subprocess.CompletedProcess(command, 0, "", "")

        snapshot = set(labels)
        labels.add("merge/auto")
        with patch.object(self.module.subprocess, "run", side_effect=github_api):
            changes = self.module.apply_labels(
                "owner/repo", 7, snapshot, {"type/bug", "status/ci-pending"}, self.config,
            )
        self.assertEqual(changes["added"], ["status/ci-pending"])
        self.assertIn("merge/auto", labels)
        self.assertFalse(any("PUT" in command for command in commands))

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
