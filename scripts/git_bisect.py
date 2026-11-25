#!/usr/bin/env python3
"""Worktree-isolated `git bisect` for automated and human-in-the-loop use.

The caller's checkout is never touched: bisecting happens in a temporary
detached worktree that is removed on exit, error, SIGINT and SIGTERM.

Check command exit codes: 0 = good, 125 = skip, anything else = bad.
Exit 126/127 (not executable / not found), timeouts, signals, and failing
`--setup` or dependency refresh also map to skip so they never yield a false
`bad` verdict.

Script exit codes: 0 culprit found, 1 no single culprit (only skipped commits
left or endpoints invalid), 2 usage or setup error, 130 aborted.

Examples:
  python3 scripts/git_bisect.py --good v1.2 -- flutter test test/foo_test.dart
  python3 scripts/git_bisect.py --good abc123 --probe /tmp/repro_test.dart:test/repro_test.dart \\
      --json -- flutter test test/repro_test.dart
  python3 scripts/git_bisect.py --good abc123 --interactive --launch 'flutter run -d chrome'
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
from contextlib import suppress
from pathlib import Path

GOOD, BAD, SKIP = "good", "bad", "skip"
SKIP_CODE = 125
FIRST_BAD = re.compile(r"^([0-9a-f]{40}) is the first '?bad'? commit", re.M)
ROOT = Path(__file__).resolve().parent.parent


class Aborted(Exception):
    """User abort or termination signal."""


def run(args, cwd, check=True, **kw):
    return subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=check, **kw)


def git(repo, *args, check=True):
    return run(["git", *args], repo, check=check).stdout.strip()


def verdict_for(code: int) -> str:
    """Map a check command's exit status to a bisect verdict."""
    if code == 0:
        return GOOD
    if code == SKIP_CODE or code in (126, 127) or code < 0:
        return SKIP
    return BAD


class Bisect:
    def __init__(self, args, repo: Path):
        self.args = args
        self.repo = repo
        self.wt: Path | None = None
        self.last_deps: str | None = None
        self.flutter: str | None = args.flutter_bin
        self.log = sys.stderr

    def say(self, msg: str) -> None:
        print(msg, file=self.log, flush=True)

    # --- worktree lifecycle ---------------------------------------------------

    def create_worktree(self, rev: str) -> None:
        self.wt = Path(tempfile.mkdtemp(prefix="bisect-"))
        git(self.repo, "worktree", "add", "--detach", "--force", str(self.wt), rev)

    def teardown(self) -> None:
        if not self.wt:
            return
        wt, self.wt = self.wt, None
        run(["git", "bisect", "reset"], wt, check=False)
        if self.args.keep_worktree:
            self.say(f"worktree kept at {wt} (remove: git worktree remove --force {wt})")
            return
        run(["git", "worktree", "remove", "--force", str(wt)], self.repo, check=False)
        shutil.rmtree(wt, ignore_errors=True)
        run(["git", "worktree", "prune"], self.repo, check=False)

    # --- step hygiene ---------------------------------------------------------

    def clean(self) -> None:
        run(["git", "reset", "-q", "--hard"], self.wt)
        run(["git", "clean", "-fdq"], self.wt)

    def link_local_files(self, linked: list[Path]) -> None:
        result = run(["bash", str(ROOT / "scripts" / "link_local_files.sh"),
                      str(self.wt), str(self.repo), "--bisect"], self.repo, check=False)
        linked.extend(self.wt / path for path in result.stdout.splitlines())
        if result.stderr:
            self.say(result.stderr.rstrip())
        result.check_returncode()

    def inject_probes(self) -> list[Path]:
        placed = []
        for spec in self.args.probe:
            src, _, dest = spec.partition(":")
            src_path = Path(src).expanduser().resolve()
            target = self.wt / (dest or src_path.name)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src_path, target)
            placed.append(target)
        return placed

    def refresh_deps(self) -> bool:
        pubspecs = [self.wt / n for n in ("pubspec.yaml", "pubspec.lock")]
        if not pubspecs[0].exists():
            return True
        digest = hashlib.sha256(b"".join(p.read_bytes() for p in pubspecs if p.exists())).hexdigest()
        if digest == self.last_deps:
            return True
        if self.flutter is None:
            out = run([sys.executable, str(ROOT / "scripts/ci/local_ci.py"), "--flutter-bin"], self.repo, check=False)
            self.flutter = out.stdout.strip() if out.returncode == 0 and out.stdout.strip() else "flutter"
        self.say("pubspec changed: refreshing dependencies")
        res = run([self.flutter, "pub", "get"], self.wt, check=False)
        if res.returncode != 0:
            self.say(f"flutter pub get failed (exit {res.returncode}): skipping commit")
            output = res.stderr.strip() or res.stdout.strip()
            if output:
                self.say(output)
            return False
        self.last_deps = digest
        return True

    def shell(self, cmd: str, timeout: float | None = None) -> int:
        env = dict(os.environ, BISECT_WORKTREE=str(self.wt))
        if self.flutter:
            env["FLUTTER_BIN"] = self.flutter
        proc = subprocess.Popen(cmd, shell=True, cwd=self.wt, env=env,
                                stdout=self.log, stderr=self.log, start_new_session=True)
        try:
            return proc.wait(timeout=timeout)
        except (subprocess.TimeoutExpired, Aborted, KeyboardInterrupt) as exc:
            with suppress(ProcessLookupError):
                os.killpg(proc.pid, signal.SIGKILL)
            proc.wait()
            if isinstance(exc, subprocess.TimeoutExpired):
                self.say(f"timeout after {timeout}s: {cmd}")
                return SKIP_CODE
            raise

    def prompt(self) -> str:
        while True:
            ans = input("[g]ood / [b]ad / [s]kip / [a]bort > ").strip().lower()
            if ans in ("g", "good"):
                return GOOD
            if ans in ("b", "bad"):
                return BAD
            if ans in ("s", "skip"):
                return SKIP
            if ans in ("a", "abort"):
                raise Aborted("aborted by user")

    def judge(self) -> str:
        """Test the commit currently checked out in the worktree."""
        self.clean()
        linked: list[Path] = []
        placed: list[Path] = []
        try:
            placed = self.inject_probes()
            self.link_local_files(linked)
            if not self.refresh_deps():
                return SKIP
            if self.args.setup and self.shell(self.args.setup, self.args.timeout) != 0:
                self.say("setup failed: skipping commit")
                return SKIP
            if self.args.interactive:
                if self.args.launch:
                    self.shell(self.args.launch)
                return self.prompt()
            return verdict_for(self.shell(self.args.command_str, self.args.timeout))
        finally:
            for p in placed:
                p.unlink(missing_ok=True)
            # A later checkout may track a path we linked for this step.
            for path in reversed(linked):
                if path.is_symlink():
                    path.unlink()

    # --- bisect ---------------------------------------------------------------

    def verify_ends(self, good: str, bad: str) -> str | None:
        for rev, want in ((good, GOOD), (bad, BAD)):
            git(self.wt, "checkout", "-q", "--detach", rev)
            got = self.judge()
            if got != want:
                return f"endpoint {rev[:9]} judged {got}, expected {want}"
        return None

    def search(self, good: str, bad: str) -> dict:
        result = {"first_bad": None, "candidates": [], "skipped": [], "steps": 0, "error": None}
        cmd = ["bisect", "start", bad, good]
        if self.args.paths:
            cmd += ["--", *self.args.paths]
        out = run(["git", *cmd], self.wt, check=False)
        text = out.stdout + out.stderr
        if out.returncode != 0:
            result["error"] = text.strip()
            return result
        tested: set[str] = set()
        while True:
            if FIRST_BAD.search(text) or "only 'skip'ped commits left" in text:
                break
            head = git(self.wt, "rev-parse", "HEAD")
            if head in tested:
                result["error"] = f"bisect did not advance past {head[:9]}"
                return result
            tested.add(head)
            verdict = self.judge()
            self.say(f"{head[:9]} -> {verdict}")
            result["steps"] += 1
            if verdict == SKIP:
                result["skipped"].append(head)
            res = run(["git", "bisect", verdict], self.wt, check=False)
            text = res.stdout + res.stderr
            done = FIRST_BAD.search(text) or "only 'skip'ped commits left" in text
            if res.returncode != 0 and not done:
                result["error"] = text.strip()
                return result
        lines = text.splitlines()
        if FIRST_BAD.search(text):
            result["first_bad"] = FIRST_BAD.search(text).group(1)
        else:
            tail = lines[next(i for i, l in enumerate(lines) if "could be any of" in l) + 1:]
            result["candidates"] = [l.strip() for l in tail if len(l.strip()) == 40]
        return result

    def provenance(self, sha: str) -> dict:
        info = {"subject": git(self.repo, "log", "-1", "--format=%s", sha),
                "stat": git(self.repo, "show", "--stat", "--format=%H%n%an%n%s", sha),
                "trace": None}
        agentctl = ROOT / "scripts/agents/agentctl"
        if agentctl.exists():
            try:
                res = run([str(agentctl), "trace", sha], self.repo, check=False, timeout=60)
                info["trace"] = res.stdout.strip() or None
            except (subprocess.TimeoutExpired, OSError):
                pass
        return info


def parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--good", required=True, help="known good revision")
    p.add_argument("--bad", default="HEAD", help="known bad revision (default HEAD)")
    p.add_argument("--paths", nargs="+", default=[], help="limit the search to commits touching these paths")
    p.add_argument("--probe", action="append", default=[], metavar="SRC[:DEST]",
                   help="copy an external reproducer into the worktree before each step (DEST relative to the worktree root, default the file name); removed afterwards")
    p.add_argument("--setup", help="shell hook run before each check (codegen, DI); failure skips the commit")
    p.add_argument("--timeout", type=float, help="per-step timeout in seconds; a timeout skips the commit")
    p.add_argument("--interactive", action="store_true", help="human-in-the-loop mode (requires a TTY)")
    p.add_argument("--launch", help="interactive mode: command to build/launch the app at each commit")
    p.add_argument("--flutter-bin", help="Flutter executable (default: scripts/ci/local_ci.py --flutter-bin)")
    p.add_argument("--verify-ends", action="store_true", help="check the good and bad endpoints before bisecting")
    p.add_argument("--keep-worktree", action="store_true", help="leave the worktree in place for debugging")
    p.add_argument("--json", action="store_true", help="print one JSON report on stdout")
    p.add_argument("--repo", default=".", help="repository to bisect (default: current)")
    p.add_argument("command", nargs=argparse.REMAINDER, help="-- <check command>")
    args = p.parse_args(argv)
    cmd = args.command[1:] if args.command[:1] == ["--"] else args.command
    args.command_str = shlex.join(cmd)
    if args.interactive:
        if not sys.stdin.isatty():
            p.error("--interactive needs a TTY; use a check command when running unattended")
    elif not cmd:
        p.error("provide a check command after `--` or use --interactive")
    return args


def main(argv=None) -> int:
    args = parse_args(argv)
    repo = Path(git(Path(args.repo), "rev-parse", "--show-toplevel"))
    b = Bisect(args, repo)

    def on_signal(signum, _frame):
        raise Aborted(f"signal {signum}")

    signal.signal(signal.SIGTERM, on_signal)
    report: dict = {}
    code = 1
    try:
        good, bad = git(repo, "rev-parse", args.good), git(repo, "rev-parse", args.bad)
        b.create_worktree(bad)
        err = b.verify_ends(good, bad) if args.verify_ends else None
        report = {"good": good, "bad": bad, "first_bad": None, "candidates": [], "skipped": [],
                  "steps": 0, "error": err}
        if not err:
            git(b.wt, "checkout", "-q", "--detach", bad)
            report.update(b.search(good, bad))
        if report["first_bad"]:
            report["culprit"] = b.provenance(report["first_bad"])
            code = 0
        elif report["error"]:
            code = 2 if report["error"] and "endpoint" not in report["error"] else 1
    except (Aborted, KeyboardInterrupt) as exc:
        report = {"error": str(exc) or "interrupted", "first_bad": None}
        code = 130
    except subprocess.CalledProcessError as exc:
        report = {"error": (exc.stderr or str(exc)).strip(), "first_bad": None}
        code = 2
    finally:
        b.teardown()
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        if report.get("first_bad"):
            c = report["culprit"]
            print(f"First bad commit: {report['first_bad']}\n{c['stat']}")
            print(f"Provenance:\n{c['trace'] or '(agentctl trace unavailable)'}")
        else:
            print(f"No culprit: {report.get('error') or 'only skipped commits left'}")
            for sha in report.get("candidates", []):
                print(f"  candidate {sha}")
        if report.get("skipped"):
            print("Skipped: " + " ".join(s[:9] for s in report["skipped"]))
    return code


if __name__ == "__main__":
    sys.exit(main())
