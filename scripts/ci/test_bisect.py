import importlib.util
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "bisect.py"
_spec = importlib.util.spec_from_file_location("bisect_cli", SCRIPT)
bisect_script = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bisect_script)


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, text=True).stdout.strip()


def commit(repo, files, msg):
    for name, text in files.items():
        (repo / name).write_text(text)
    git(repo, "add", "-A")
    git(repo, "-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-q", "-m", msg)
    return git(repo, "rev-parse", "HEAD")


class VerdictMapping(unittest.TestCase):
    def test_exit_codes(self):
        v = bisect_script.verdict_for
        self.assertEqual(v(0), "good")
        self.assertEqual(v(1), "bad")
        self.assertEqual(v(2), "bad")
        self.assertEqual(v(125), "skip")
        self.assertEqual(v(127), "skip")
        self.assertEqual(v(-9), "skip")


class BisectRepo(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        self.shas = [commit(self.repo, {"value.txt": str(n)}, f"c{n}") for n in range(1, 7)]
        self.head = git(self.repo, "rev-parse", "HEAD")

    def tearDown(self):
        self._tmp.cleanup()

    def bisect(self, *extra, check=("sh", "-c", 'test "$(cat value.txt)" -lt 4')):
        proc = subprocess.run([sys.executable, str(SCRIPT), "--repo", str(self.repo), "--json", *extra, "--", *check],
                              capture_output=True, text=True, timeout=120)
        return proc, (json.loads(proc.stdout) if proc.stdout.strip() else {})

    def assert_clean(self):
        self.assertEqual(git(self.repo, "worktree", "list").count("\n"), 0)
        self.assertEqual(git(self.repo, "rev-parse", "HEAD"), self.head)
        self.assertEqual(git(self.repo, "status", "--porcelain"), "")
        self.assertEqual(git(self.repo, "branch", "--show-current"), "main")

    def test_finds_first_bad_commit(self):
        proc, report = self.bisect("--good", self.shas[0])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(report["first_bad"], self.shas[3])
        self.assertEqual(report["culprit"]["subject"], "c4")
        self.assert_clean()

    def test_probe_is_injected_from_outside_the_tree(self):
        probe = self.tmp / "probe.py"
        probe.write_text("import sys\nsys.exit(0 if int(open('value.txt').read()) < 4 else 1)\n")
        proc, report = self.bisect("--good", self.shas[0], "--probe", str(probe), check=("python3", "probe.py"))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(report["first_bad"], self.shas[3])
        self.assertFalse((self.repo / "probe.py").exists())
        self.assert_clean()

    def test_skipped_commits_leave_candidates(self):
        repo = self.tmp / "skip"
        repo.mkdir()
        git(repo, "init", "-q", "-b", "main")
        good = commit(repo, {"value.txt": "1"}, "good")
        broken = commit(repo, {"value.txt": "2", "broken": ""}, "broken")
        bad = commit(repo, {"value.txt": "9"}, "bad")
        check = ["sh", "-c", 'test ! -e broken || exit 125; test "$(cat value.txt)" -lt 4']
        proc = subprocess.run([sys.executable, str(SCRIPT), "--repo", str(repo), "--json", "--good", good, "--", *check],
                              capture_output=True, text=True, timeout=120)
        report = json.loads(proc.stdout)
        self.assertEqual(proc.returncode, 1)
        self.assertIsNone(report["first_bad"])
        self.assertEqual(sorted(report["candidates"]), sorted([broken, bad]))
        self.assertIn(broken, report["skipped"])

    def test_timeout_and_failing_setup_skip(self):
        for extra in (["--timeout", "1"], ["--setup", "false"]):
            proc, report = self.bisect("--good", self.shas[0], *extra, check=("sleep", "5"))
            self.assertEqual(proc.returncode, 1, proc.stderr)
            self.assertIsNone(report["first_bad"])
            self.assertTrue(report["skipped"])
        self.assert_clean()

    def test_pubspec_change_refreshes_dependencies(self):
        repo = self.tmp / "pub"
        repo.mkdir()
        git(repo, "init", "-q", "-b", "main")
        good = commit(repo, {"pubspec.yaml": "a", "value.txt": "1"}, "good")
        commit(repo, {"pubspec.yaml": "b"}, "deps")
        commit(repo, {"value.txt": "9"}, "bad")
        fake = self.tmp / "flutter"
        log = self.tmp / "pub.log"
        fake.write_text(f"#!/bin/sh\necho \"$@\" >> {log}\n")
        fake.chmod(0o755)
        proc = subprocess.run([sys.executable, str(SCRIPT), "--repo", str(repo), "--json", "--good", good,
                               "--flutter-bin", str(fake), "--", "sh", "-c", 'test "$(cat value.txt)" -lt 4'],
                              capture_output=True, text=True, timeout=120)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("pub get", log.read_text())

    def test_sigterm_removes_worktree(self):
        proc = subprocess.Popen([sys.executable, str(SCRIPT), "--repo", str(self.repo), "--good", self.shas[0],
                                 "--", "sleep", "30"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        deadline = time.time() + 30
        while time.time() < deadline and git(self.repo, "worktree", "list").count("\n") < 1:
            time.sleep(0.1)
        time.sleep(1)
        proc.send_signal(signal.SIGTERM)
        proc.communicate(timeout=60)
        self.assertEqual(proc.returncode, 130)
        self.assert_clean()
        self.assertEqual(git(self.repo, "for-each-ref", "refs/bisect"), "")


if __name__ == "__main__":
    unittest.main()
