#!/usr/bin/env python3
import importlib.util
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("local_ci", ROOT / "scripts/ci/local_ci.py")
ci = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["local_ci"] = ci
spec.loader.exec_module(ci)


def first_paths(workflow: str) -> set[str]:
    """Items of the first `paths:` list in a workflow file."""
    lines = (ROOT / ".github/workflows" / workflow).read_text().splitlines()
    start = next(i for i, line in enumerate(lines) if line.strip().startswith("paths:"))
    items = []
    for line in lines[start + 1:]:
        match = re.match(r"\s*- ['\"]?(.+?)['\"]?\s*$", line)
        if not match:
            break
        items.append(match.group(1))
    return set(items)


class LocalCiTest(unittest.TestCase):
    def test_glob_semantics_match_github_path_filters(self):
        self.assertTrue(ci.glob_re("**.dart").match("lib/a/b.dart"))
        self.assertTrue(ci.glob_re("**.dart").match("main.dart"))
        self.assertTrue(ci.glob_re("*.md").match("README.md"))
        self.assertFalse(ci.glob_re("*.md").match("doc/a.md"))
        self.assertTrue(ci.glob_re(".agents/**").match(".agents/skills/x/SKILL.md"))
        self.assertFalse(ci.glob_re("lib/**").match("library.txt"))

    def test_groups_for_changed_files(self):
        self.assertEqual(ci.groups_for(["lib/main.dart"]), ["dart"])
        self.assertEqual(ci.groups_for(["specs/source-of-truth/status.md"]), ["agents", "docs"])
        self.assertEqual(ci.groups_for([".github/workflows/merge-gate.yml"]), ["agents", "workflows"])
        self.assertEqual(ci.groups_for(["Makefile"]), [])

    def test_group_paths_match_their_workflows(self):
        self.assertEqual(set(ci.GROUPS["agents"].paths), first_paths("agent-system.yml"))
        self.assertEqual(set(ci.GROUPS["docs"].paths) | {"scripts/ci/local_ci.py"}, first_paths("docs-pages.yml"))
        self.assertEqual(set(ci.GROUPS["dart"].paths), first_paths("ci-checks.yml"))

    def test_workflows_run_the_same_commands(self):
        workflows = ROOT / ".github/workflows"
        self.assertIn("scripts/ci/local_ci.py --group agents", (workflows / "agent-system.yml").read_text())
        self.assertIn("scripts/ci/local_ci.py --group docs", (workflows / "docs-pages.yml").read_text())
        checks = (workflows / "ci-checks.yml").read_text()
        for command in ci.GROUPS["dart"].commands:
            self.assertIn(" ".join(command), checks)

    def test_pre_push_skips_branch_deletions(self):
        zero = "0" * 40
        self.assertTrue(ci.pushes_only_deletions(f"(delete) {zero} refs/heads/x abc\n"))
        self.assertFalse(ci.pushes_only_deletions(f"refs/heads/x abc refs/heads/x {zero}\n"))


if __name__ == "__main__":
    unittest.main()
