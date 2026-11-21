#!/usr/bin/env python3
"""Run the CI checks for the areas a branch changes, locally, before pushing.

Groups mirror CI workflows (ADR 0006). `agents` and `docs` are the exact
commands their workflows run; `dart` is kept equal to ci-checks.yml by
test_local_ci.py. A passing group is cached per clean tree.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE = ROOT / ".agents/state/local-ci"
CI_ONLY = "Web/Android smoke, E2E, Android integration, Firestore rules, dependency review"

AGENT_JSON = [
    ".agents/policies/default.json", ".agents/github/labels.json", ".agents/policies/schema.json",
    ".agents/runners/providers.json", ".agents/runners/router.json", ".agents/workflows/schema.json",
    ".agents/workflows/result.schema.json", ".agents/policies/agent-implement.json",
]


@dataclass
class Group:
    paths: list[str]
    commands: list[list[str]]
    env: dict[str, str] = field(default_factory=dict)


GROUPS: dict[str, Group] = {
    "agents": Group(
        paths=[
            ".agents/**", "AGENTS.md", "CLAUDE.md", "GEMINI.md", "scripts/agents/**", "scripts/github/**",
            "scripts/secrets/**", "scripts/ci/local_ci.py", "scripts/ci/test_local_ci.py", ".githooks/**", ".agents/github/**",
            ".github/workflows/github-labels.yml", ".github/workflows/merge-gate.yml", "specs/**", "docs/**", "doc/**",
            ".github/workflows/agent-system.yml", ".claude/**", ".gemini/**", ".github/agents/**",
            ".github/instructions/**", ".github/copilot-instructions.md", ".github/workflows/agent-implement.yml",
            "scripts/human/**",
        ],
        commands=[
            ["python3", "-m", "py_compile", "scripts/agents/agentctl.py", "scripts/agents/agent_skills.py",
             "scripts/agents/session_query.py"],
            ["python3", "-m", "unittest", "scripts/agents/test_agentctl.py"],
            ["python3", "-m", "unittest", "scripts/agents/test_agent_skills.py"],
            ["scripts/agents/agentctl", "skills", "check"],
            ["python3", "-m", "unittest", "scripts/github/test_sync_labels.py"],
            ["python3", "-m", "unittest", "scripts/github/test_merge_gate.py"],
            ["python3", "-m", "unittest", "scripts/secrets/test_rotate.py"],
            ["python3", "-m", "unittest", "scripts/ci/test_local_ci.py"],
            ["scripts/agents/agentctl", "heal"],
            ["scripts/agents/agentctl", "workflow", "validate", ".agents/workflows/repository-health.json"],
            ["scripts/agents/agentctl", "router", "plan", ".agents/workflows/repository-health.json"],
            ["scripts/agents/agentctl", "workflow", "validate", ".agents/workflows/implement-issue.json"],
            ["env", "AGENT_POLICY_FILE=.agents/policies/agent-implement.json",
             "scripts/agents/agentctl", "workflow", "plan", ".agents/workflows/implement-issue.json"],
            ["scripts/agents/agentctl", "doctor"],
            *[["scripts/agents/agentctl", "policy", "compile", "--provider", p]
              for p in ("codex", "claude", "opencode", "gemini", "vibe", "copilot")],
            *[["python3", "-m", "json.tool", f] for f in AGENT_JSON],
        ],
    ),
    "docs": Group(
        paths=["doc/**", "specs/source-of-truth/**", "assets/logos/**", "*.md", "mkdocs.yml", "scripts/docs/**",
               ".github/workflows/docs-pages.yml"],
        commands=[
            ["{python}", "scripts/docs/prepare.py"],
            ["{python}", "-m", "mkdocs", "build", "--strict"],
            ["{python}", "scripts/docs/check_site.py", "build/docs-site"],
        ],
    ),
    "dart": Group(
        paths=["**.dart", "lib/**", "test/**", "assets/translations/**", "pubspec.yaml", "pubspec.lock",
               "analysis_options.yaml", "android/**", "web/**", "integration_test/**", "test_driver/**"],
        commands=[
            ["flutter", "pub", "get"],
            ["dart", "format", "--output=none", "--set-exit-if-changed", "."],
            ["dart", "run", "build_runner", "build", "--delete-conflicting-outputs"],
            ["flutter", "analyze", "--fatal-infos", "--fatal-warnings", "--no-pub"],
            ["dart", "run", "scripts/locale/check_localizations.dart"],
            ["dart", "run", "scripts/ci/check_shape_sync.dart"],
            ["dart", "run", "scripts/ci/select_tests.dart"],
            ["dart", "run", "scripts/ci/run_tests.dart"],
        ],
    ),
    "workflows": Group(paths=[".github/workflows/**"], commands=[["actionlint"]]),
}


def glob_re(pattern: str) -> re.Pattern[str]:
    """GitHub Actions path-filter semantics: `**` crosses `/`, `*` does not."""
    out = ""
    i = 0
    while i < len(pattern):
        if pattern.startswith("**", i):
            out += ".*"
            i += 2
        elif pattern[i] == "*":
            out += "[^/]*"
            i += 1
        else:
            out += re.escape(pattern[i])
            i += 1
    return re.compile(out + r"\Z")


def groups_for(files: list[str]) -> list[str]:
    return [name for name, group in GROUPS.items()
            if any(glob_re(p).match(f) for p in group.paths for f in files)]


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()


def changed_files(base: str) -> list[str]:
    merge_base = git("merge-base", base, "HEAD")
    committed = git("diff", "--name-only", merge_base, "HEAD").splitlines()
    dirty = [line[3:].split(" -> ")[-1] for line in git("status", "--porcelain").splitlines()]
    return sorted(set(committed + dirty))


def ci_flutter_version() -> str | None:
    match = re.search(r"flutter-version:\s*([\d.]+)", (ROOT / ".github/workflows/ci-checks.yml").read_text())
    return match.group(1) if match else None


def local_flutter_version(flutter: str = "flutter") -> str | None:
    try:
        out = subprocess.run([flutter, "--version", "--machine"], cwd=ROOT, capture_output=True, text=True, timeout=600)
        return json.loads(out.stdout[out.stdout.index("{"):]).get("frameworkVersion")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None


def pinned_flutter_bin(version: str) -> Path:
    """Flutter at CI's pinned version, cloned once per machine and shared by worktrees."""
    cache = Path(os.environ.get("LOCAL_CI_FLUTTER_CACHE")
                 or Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "foodsavr-local-ci")
    sdk = cache / f"flutter-{version}"
    cache.mkdir(parents=True, exist_ok=True)
    with open(cache / f"flutter-{version}.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not (sdk / "bin/flutter").exists():
            print(f"local-ci: installing Flutter {version} into {sdk} (once per machine)", flush=True)
            subprocess.run(["git", "clone", "-q", "--depth", "1", "--branch", version,
                            "https://github.com/flutter/flutter.git", str(sdk)], check=True)
        if local_flutter_version(str(sdk / "bin/flutter")) != version:
            raise RuntimeError(f"{sdk} does not report Flutter {version}")
    return sdk / "bin"


def docs_python() -> str:
    """Interpreter with the pinned docs tools; a cached venv when not installed."""
    if os.environ.get("LOCAL_CI_PYTHON"):
        return os.environ["LOCAL_CI_PYTHON"]
    if subprocess.run([sys.executable, "-c", "import mkdocs, material"], capture_output=True).returncode == 0:
        return sys.executable
    requirements = ROOT / "scripts/docs/requirements.txt"
    venv = STATE / "docs-venv"
    stamp = venv / "requirements.sha256"
    digest = hashlib.sha256(requirements.read_bytes()).hexdigest()
    python = venv / "bin/python"
    if not (python.exists() and stamp.exists() and stamp.read_text() == digest):
        subprocess.run([sys.executable, "-m", "venv", "--clear", str(venv)], check=True, capture_output=True)
        subprocess.run([str(python), "-m", "pip", "install", "-q", "-r", str(requirements)], check=True, capture_output=True)
        stamp.write_text(digest)
    return str(python)


FIREBASE_STUB = """// Compile-only stub written by scripts/ci/local_ci.py; removed after the run.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
    apiKey: 'local-ci',
    appId: 'local-ci',
    messagingSenderId: 'local-ci',
    projectId: 'local-ci',
  );
}
"""
# CI writes these from secrets / `touch`; locally they may be absent.
CI_FILES = {"lib/firebase_options.dart": FIREBASE_STUB, "assets/.env": ""}
RESTORED = ["analysis_options.yaml", "pubspec.lock"]


@dataclass
class Result:
    group: str
    status: str  # PASS | FAIL | SKIP | CACHED
    detail: str = ""
    seconds: float = 0.0
    output: str = ""


def precheck(name: str) -> str | None:
    """Return a skip reason when this machine cannot mirror the group."""
    if name == "dart":
        if not shutil.which("flutter"):
            return "flutter not on PATH"
        options = ROOT / "lib/firebase_options.dart"
        if options.exists() and "DefaultFirebaseOptions" not in options.read_text(errors="replace"):
            return "lib/firebase_options.dart is invalid (regenerate with flutterfire configure)"
        for rel in CI_FILES:
            if (ROOT / rel).is_symlink() and not (ROOT / rel).exists():
                return f"{rel} is a dangling symlink"
    if name == "workflows" and not shutil.which("actionlint"):
        return "actionlint not installed"
    return None


def run_group(name: str, stream: bool) -> Result:
    start = time.monotonic()
    reason = precheck(name)
    if reason:
        return Result(name, "SKIP", reason)
    group = GROUPS[name]
    env = {**os.environ, **group.env}
    commands = group.commands
    if name == "docs":
        try:
            python = docs_python()
        except subprocess.CalledProcessError as error:
            return Result(name, "SKIP", f"cannot install docs tools: {(error.stderr or b'')[-200:]!r}")
        commands = [[python if part == "{python}" else part for part in cmd] for cmd in commands]
    if name == "dart":
        local, ci = local_flutter_version(), ci_flutter_version()
        if ci and local != ci:
            try:
                env["PATH"] = f"{pinned_flutter_bin(ci)}{os.pathsep}{env['PATH']}"
            except (RuntimeError, subprocess.CalledProcessError) as error:
                return Result(name, "SKIP", f"local Flutter {local}, CI {ci}; pinned SDK unavailable: {error}")
    if name == "workflows":
        commands = [["actionlint", *changed_workflows]] if changed_workflows else commands
    created = [ROOT / rel for rel in CI_FILES if name == "dart" and not (ROOT / rel).exists()]
    for path in created:
        path.write_text(CI_FILES[str(path.relative_to(ROOT))])
    # `flutter pub get` rewrites these; CI restores analysis options before analyzing.
    snapshot = {rel: (ROOT / rel).read_bytes() for rel in RESTORED if name == "dart" and (ROOT / rel).exists()}
    try:
        return run_commands(commands, env, stream, start, name, snapshot)
    finally:
        for path in created:
            path.unlink(missing_ok=True)
        for rel, data in snapshot.items():
            if (ROOT / rel).read_bytes() != data:
                (ROOT / rel).write_bytes(data)


def run_commands(commands: list[list[str]], env: dict[str, str], stream: bool, start: float, name: str,
                 snapshot: dict[str, bytes]) -> Result:
    log: list[str] = []
    for cmd in commands:
        selects = cmd[-1] == "scripts/ci/select_tests.dart"
        out = subprocess.run(cmd, cwd=ROOT, env=env, text=True,
                             stdout=None if stream and not selects else subprocess.PIPE, stderr=subprocess.STDOUT)
        text = out.stdout or ""
        if stream and selects:
            print(text, end="", flush=True)
        log.append(f"$ {' '.join(cmd)}\n{text}")
        if out.returncode != 0:
            return Result(name, "FAIL", f"{' '.join(cmd)} (exit {out.returncode})",
                          time.monotonic() - start, "".join(log))
        if cmd == ["flutter", "pub", "get"] and "analysis_options.yaml" in snapshot:
            (ROOT / "analysis_options.yaml").write_bytes(snapshot["analysis_options.yaml"])
        if selects:
            match = re.search(r"^files=(.*)$", text, re.MULTILINE)
            env["SELECTED_FILES"] = match.group(1) if match else "ALL"
    return Result(name, "PASS", "", time.monotonic() - start)


changed_workflows: list[str] = []


def cache_key(name: str) -> Path | None:
    if git("status", "--porcelain"):
        return None
    return STATE / f"pass-{name}-{git('rev-parse', 'HEAD^{tree}')}"


def pushes_only_deletions(stdin: str) -> bool:
    lines = [line.split() for line in stdin.splitlines() if line.strip()]
    return bool(lines) and all(len(p) == 4 and set(p[1]) == {"0"} for p in lines)


def main(argv: list[str] | None = None) -> int:
    global changed_workflows
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--group", action="append", choices=sorted(GROUPS), help="run these groups (CI uses this)")
    parser.add_argument("--all", action="store_true", help="run every group")
    parser.add_argument("--base", default=os.environ.get("LOCAL_CI_BASE", "origin/main"))
    parser.add_argument("--list", action="store_true", help="print the plan without running")
    parser.add_argument("--no-cache", action="store_true")
    parser.add_argument("--pre-push", action="store_true", help="git pre-push hook mode")
    args = parser.parse_args(argv)
    if args.pre_push and not sys.stdin.isatty() and pushes_only_deletions(sys.stdin.read()):
        return 0
    files: list[str] = []
    if args.group:
        names = args.group
    elif args.all:
        names = list(GROUPS)
    else:
        try:
            files = changed_files(args.base)
        except subprocess.CalledProcessError:
            print(f"local-ci: {args.base} not found; running every group")
            names = list(GROUPS)
        else:
            names = groups_for(files)
    changed_workflows = [f for f in files if glob_re(".github/workflows/**").match(f) and (ROOT / f).exists()]
    print(f"local-ci: {len(files)} changed file(s) vs {args.base}; groups: {', '.join(names) or 'none'}")
    if args.list or not names:
        return 0
    STATE.mkdir(parents=True, exist_ok=True)
    results: list[Result] = []
    todo: list[str] = []
    for name in names:
        key = None if args.no_cache else cache_key(name)
        if key and key.exists():
            results.append(Result(name, "CACHED", "passed on this tree"))
        else:
            todo.append(name)
    # Live output only in CI logs; locally print the failing tail instead.
    stream = len(todo) == 1 and os.environ.get("GITHUB_ACTIONS") == "true"
    with ThreadPoolExecutor(max_workers=max(len(todo), 1)) as pool:
        for result in pool.map(lambda n: run_group(n, stream), todo):
            results.append(result)
            if result.status == "PASS" and (key := cache_key(result.group)):
                key.touch()
    for r in results:
        print(f"  {r.group:<10}{r.status:<7}{f'{r.seconds:5.1f}s ' if r.seconds else ''}{r.detail}")
    for r in results:
        if r.status == "FAIL" and r.output:
            print(f"\n--- {r.group} ---\n" + "\n".join(r.output.splitlines()[-60:]))
    print(f"CI only: {CI_ONLY}")
    return 1 if any(r.status == "FAIL" for r in results) else 0


if __name__ == "__main__":
    sys.exit(main())
