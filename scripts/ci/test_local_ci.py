#!/usr/bin/env python3
import importlib.util
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

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
        self.assertEqual(ci.groups_for(["Makefile"]), ["agents"])
        self.assertEqual(ci.groups_for(["README.md"]), ["docs"])

    def test_group_paths_match_their_workflows(self):
        self.assertEqual(set(ci.GROUPS["agents"].paths), first_paths("agent-system.yml"))
        self.assertEqual(set(ci.GROUPS["docs"].paths) | {"scripts/ci/local_ci.py"}, first_paths("docs-pages.yml"))
        self.assertEqual(set(ci.GROUPS["dart"].paths), first_paths("ci-checks.yml"))

    def test_python_tests_are_discovered_per_directory(self):
        commands = ci.GROUPS["agents"].commands
        for directory in ci.PYTHON_TEST_DIRS:
            self.assertIn(["python3", "-m", "unittest", "discover", "-s", f"scripts/{directory}", "-p", "test_*.py"],
                          commands)
            self.assertTrue(any((ROOT / "scripts" / directory).glob("test_*.py")), directory)
        self.assertFalse([c for c in commands if c[:3] == ["python3", "-m", "unittest"] and c[3] != "discover"])
        # Every test file in an uncovered directory must be a conscious exclusion, not an oversight.
        uncovered = {p.parent.name for p in (ROOT / "scripts").glob("*/test_*.py")} - set(ci.PYTHON_TEST_DIRS)
        self.assertEqual(uncovered, {"infra"})

    def test_new_ci_scripts_trigger_the_agents_group(self):
        self.assertEqual(ci.groups_for(["scripts/ci/validation_status.py"]), ["agents", "dart"])
        self.assertEqual(ci.groups_for(["scripts/ci/test_validation_status.py"]), ["agents", "dart"])
        self.assertEqual(ci.groups_for(["scripts/setup/test_setupctl.py"]), ["agents"])

    def test_workflows_run_the_same_commands(self):
        workflows = ROOT / ".github/workflows"
        self.assertIn("scripts/ci/local_ci.py --group agents", (workflows / "agent-system.yml").read_text())
        self.assertIn("scripts/ci/local_ci.py --group docs", (workflows / "docs-pages.yml").read_text())
        checks = (workflows / "ci-checks.yml").read_text()
        for command in ci.GROUPS["dart"].commands:
            self.assertIn(" ".join(command), checks)

    def test_make_check_bootstraps_and_cleans_up_after_failure(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(ci, "ROOT", Path(directory)):
            for item in ("lib", "assets"):
                (ci.ROOT / item).mkdir()
            analysis = ci.ROOT / "analysis_options.yaml"
            analysis.write_text("original")
            commands = []

            def run(command, **kwargs):
                commands.append(command)
                self.assertTrue((ci.ROOT / "assets/.env").is_file())
                self.assertIn("DefaultFirebaseOptions", (ci.ROOT / "lib/firebase_options.dart").read_text())
                if command == ["flutter", "pub", "get"]:
                    analysis.write_text("rewritten")
                else:
                    self.assertEqual(analysis.read_text(), "original")
                code = int(command[-1] == "_run-checks")
                return ci.subprocess.CompletedProcess(command, code, None)

            with patch.object(ci, "precheck", return_value=None), \
                    patch.object(ci, "dart_environment"), \
                    patch.object(ci.subprocess, "run", side_effect=run):
                self.assertEqual(ci.make_check("make"), 1)
            self.assertEqual(commands, [
                ["flutter", "pub", "get"],
                ["make", "build"],
                ["make", "-o", ".deps-stamp", "_run-checks"],
            ])
            for rel in ci.CI_FILES:
                self.assertFalse((ci.ROOT / rel).exists())
            self.assertEqual(analysis.read_text(), "original")

    def test_dart_workspace_preserves_existing_ci_files(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(ci, "ROOT", Path(directory)):
            (ci.ROOT / "lib").mkdir()
            (ci.ROOT / "assets").mkdir()
            options = ci.ROOT / "lib/firebase_options.dart"
            dotenv = ci.ROOT / "assets/.env"
            options.write_text("custom options")
            dotenv.write_text("FOO=bar\n")
            with ci.dart_workspace():
                self.assertEqual(options.read_text(), "custom options")
                self.assertEqual(dotenv.read_text(), "FOO=bar\n")
            self.assertEqual(options.read_text(), "custom options")
            self.assertEqual(dotenv.read_text(), "FOO=bar\n")

    def test_flutter_bin_prints_selected_executable(self):
        import io
        from contextlib import redirect_stdout

        def fake_dart_env(env):
            env["PATH"] = "/pinned/flutter/bin:" + env.get("PATH", "")

        stdout = io.StringIO()
        with patch.object(ci, "dart_environment", side_effect=fake_dart_env), \
                patch.object(ci.shutil, "which", return_value="/pinned/flutter/bin/flutter") as which, \
                redirect_stdout(stdout):
            code = ci.main(["--flutter-bin"])
        self.assertEqual(code, 0)
        self.assertEqual(stdout.getvalue().strip(), "/pinned/flutter/bin/flutter")
        which.assert_called_once()
        self.assertTrue(which.call_args.kwargs["path"].startswith("/pinned/flutter/bin:"))

    def test_pre_push_skips_branch_deletions(self):
        zero = "0" * 40
        self.assertTrue(ci.pushes_only_deletions(f"(delete) {zero} refs/heads/x abc\n"))
        self.assertFalse(ci.pushes_only_deletions(f"refs/heads/x abc refs/heads/x {zero}\n"))


if __name__ == "__main__":
    unittest.main()
