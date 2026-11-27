#!/usr/bin/env python3
"""List or run the tests affected by changed files.

Files come from the arguments, else from the branch and working tree against
`--base` (default origin/develop). Dart tests are selected by import closure and by
matching name (`foo.dart` -> `foo_test.dart`), Python tests by name and by the files
they reference, and Playwright specs by path heuristics.

This is a fast local check, not a gate: PR CI and the nightly run remain the
verification. `--run` runs without coverage. Playwright needs the web build served on
BASE_URL and the Firebase Emulators (test/e2e).
"""

from __future__ import annotations

import argparse
import os
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import local_ci  # noqa: E402

ROOT = local_ci.ROOT
E2E = "test/e2e"
SMOKE_SPEC = "app.smoke.spec.ts"
# lib/ path fragments that select a Playwright spec besides the smoke spec.
SPEC_KEYWORDS = {
    "auth.spec.ts": ("auth", "login", "sign_in"),
    "collections.spec.ts": ("collection", "inventory", "shopping"),
    "transfers.spec.ts": ("transfer",),
    "navigation.spec.ts": ("router", "route", "navigation", "dashboard", "main_view"),
    "landing.spec.ts": ("lib/main.dart",),
    "startup_and_pwa.spec.ts": ("pwa", "startup", "splash", "app_theme", "lib/main.dart"),
}
# Changes that can affect every Dart test; a relevant slice cannot cover them.
DART_GLOBAL = ("pubspec.yaml", "pubspec.lock", "analysis_options.yaml")
PACKAGE_INPUTS = ("pubspec.yaml", "analysis_options.yaml")
# Roots whose non-Python files Python tests assert on (workflows, hooks, shell scripts).
PYTHON_SCOPES = ("scripts/", ".github/", ".githooks/", ".agents/", "make/")
# Basenames too common to identify a file without its directory.
GENERIC_NAMES = {"__init__.py", "action.yml", "README.md", "SKILL.md", "config.json"}
DIRECTIVE = re.compile(r"^\s*(?:import|export|part)\s+[^;]*;", re.MULTILINE)
DART_URI = re.compile(r"""['"]([^'"]+\.dart)['"]""")


@dataclass(frozen=True)
class Command:
    argv: tuple[str, ...]
    cwd: str = "."

    def __str__(self) -> str:
        line = shlex.join(self.argv)
        return line if self.cwd == "." else f"(cd {shlex.quote(self.cwd)} && {line})"


def dart_packages() -> dict[str, str]:
    """Own package name -> directory prefix of the package ('' is the app)."""
    packages = {}
    for pubspec in [ROOT / "pubspec.yaml", *sorted(ROOT.glob("packages/*/pubspec.yaml"))]:
        if pubspec.is_file() and (match := re.search(r"^name:\s*(\S+)", pubspec.read_text(), re.MULTILINE)):
            parent = pubspec.parent.relative_to(ROOT).as_posix()
            packages[match.group(1)] = "" if parent == "." else f"{parent}/"
    return packages


def dart_closure(entry: str, packages: dict[str, str]) -> set[str]:
    """Own files reachable from entry. Missing (deleted) files stay in the closure."""
    seen: set[str] = set()
    queue = [entry]
    while queue:
        file = queue.pop()
        if file in seen:
            continue
        seen.add(file)
        path = ROOT / file
        if not path.is_file():
            continue
        for directive in DIRECTIVE.findall(path.read_text(errors="replace")):
            for uri in DART_URI.findall(directive):
                if uri.startswith("package:"):
                    name, _, rest = uri.removeprefix("package:").partition("/")
                    if name in packages:
                        queue.append(f"{packages[name]}lib/{rest}")
                elif not uri.startswith("dart:"):
                    queue.append(os.path.normpath(f"{os.path.dirname(file)}/{uri}"))
    return seen


def dart_tests(files: list[str]) -> dict[str, list[str]]:
    """Affected tests per package prefix."""
    packages = dart_packages()
    changed = {f for f in files if f.endswith(".dart")}
    names = {f"{Path(f).stem}_test.dart": f for f in changed if "lib/" in f}
    selected: dict[str, list[str]] = {}
    for prefix in sorted(set(packages.values())):
        whole = bool(prefix) and any(f"{prefix}{name}" in files for name in PACKAGE_INPUTS)
        if not (changed or whole):
            continue
        for path in sorted((ROOT / f"{prefix}test").rglob("*_test.dart")):
            test = path.relative_to(ROOT).as_posix()
            named = path.name in names and names[path.name].startswith(f"{prefix}lib/")
            if whole or named or dart_closure(test, packages) & changed:
                selected.setdefault(prefix, []).append(test)
    return selected


def is_python_test(path: str) -> bool:
    name = Path(path).name
    return name.endswith(".py") and (name.startswith("test_") or name.endswith("_test.py"))


def python_tests(files: list[str]) -> list[str]:
    tests = {p.relative_to(ROOT).as_posix(): p for p in (ROOT / "scripts").rglob("*.py") if is_python_test(p.name)}
    sources = {name: path.read_text(errors="replace") for name, path in tests.items()}
    selected: set[str] = set()
    for file in files:
        if file in tests:
            selected.add(file)
            continue
        if not file.startswith(PYTHON_SCOPES) or file.startswith(".agents/events/") or file.endswith(".jsonl"):
            continue
        path = Path(file)
        reference = f"{path.parent.name}/{path.name}" if path.name in GENERIC_NAMES else path.name
        patterns = [rf"(?<![\w.-]){re.escape(reference)}(?![\w-])"]
        if path.suffix == ".py" and path.name not in GENERIC_NAMES:
            patterns.append(rf"^\s*(?:from\s+(?:[\w.]+\.)?{path.stem}\s+import|"
                            rf"(?:from\s+[\w.]+\s+)?import\s+(?:[\w.]+\.)?{path.stem}\b)")
        pattern = re.compile("|".join(patterns), re.MULTILINE)
        for name, source in sources.items():
            sibling = Path(name).parent == path.parent and Path(name).name == f"test_{path.stem}.py"
            if sibling or pattern.search(source):
                selected.add(name)
    return sorted(selected)


def playwright_specs(files: list[str]) -> list[str]:
    available = sorted(p.name for p in (ROOT / E2E / "tests").glob("*.spec.ts"))
    selected: set[str] = set()
    for file in files:
        if file.startswith(f"{E2E}/tests/") and file.endswith(".spec.ts"):
            selected.add(Path(file).name)
        elif file.startswith(f"{E2E}/") and not file.endswith(".md"):
            selected.update(available)  # shared helpers, setup or config
        elif file.startswith("web/about/"):
            selected.add("about.spec.ts")
        elif file.startswith("web/"):
            selected.update({SMOKE_SPEC, "landing.spec.ts", "startup_and_pwa.spec.ts"})
        elif file.startswith(("lib/", "assets/", "packages/foodsavr_core/lib/")) or file == "pubspec.yaml":
            selected.add(SMOKE_SPEC)
            if file.startswith("lib/"):
                selected.update(spec for spec, words in SPEC_KEYWORDS.items() if any(w in file for w in words))
    return [f"tests/{spec}" for spec in available if spec in selected]


def commands_for(files: list[str]) -> list[Command]:
    commands = []
    for prefix, tests in dart_tests(files).items():
        if prefix:
            commands.append(Command(("dart", "test", *(t.removeprefix(prefix) for t in tests)), prefix.rstrip("/")))
        else:
            commands.append(Command(("flutter", "test", *tests)))
    for test in python_tests(files):
        path = Path(test)
        commands.append(Command(("python3", "-m", "unittest", "discover", "-s", path.parent.as_posix(),
                                 "-p", path.name)))
    if specs := playwright_specs(files):
        commands.append(Command(("npx", "playwright", "test", "--project=smoke", "--project=chromium", *specs), E2E))
    return commands


def input_files(paths: list[str], base: str) -> list[str]:
    if paths:
        files = []
        for raw in paths:
            path = Path(raw)
            absolute = (path if path.is_absolute() else Path.cwd() / path).resolve()
            if not absolute.is_relative_to(ROOT):
                raise ValueError(f"{raw} is outside the repository")
            relative = absolute.relative_to(ROOT).as_posix()
            if absolute.is_dir():
                files += local_ci.git("ls-files", "--cached", "--others", "--exclude-standard",
                                      "--", relative).splitlines()
            else:
                files.append(relative)
        return sorted(set(files))
    # `git status` collapses a new directory into one entry; list its files instead.
    untracked = local_ci.git("ls-files", "--others", "--exclude-standard").splitlines()
    return sorted({f for f in [*local_ci.changed_files(base), *untracked] if not f.endswith("/")})


def run(commands: list[Command]) -> int:
    env = dict(os.environ)
    dart = any(c.argv[0] in {"flutter", "dart"} for c in commands)
    if dart:
        local_ci.dart_environment(env)
    failed = []

    def execute(command: Command) -> None:
        print(f"$ {command}", flush=True)
        try:
            code = subprocess.run(command.argv, cwd=ROOT / command.cwd, env=env).returncode
        except OSError as error:
            print(f"relevant-tests: {error}", file=sys.stderr)
            code = 127
        if code:
            failed.append(command)

    dart_commands = [c for c in commands if c.argv[0] in {"flutter", "dart"}]
    if dart_commands:
        # Writes the untracked files Flutter needs and restores what pub get rewrites.
        with local_ci.dart_workspace():
            for command in dart_commands:
                execute(command)
    for command in commands:
        if command not in dart_commands:
            execute(command)
    for command in failed:
        print(f"relevant-tests: FAILED {command}", file=sys.stderr)
    return 1 if failed else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="*", help="changed files or directories (default: the diff against --base)")
    parser.add_argument("--base", default=os.environ.get("LOCAL_CI_BASE", "origin/develop"))
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--print", action="store_true", help="list the commands (default)")
    mode.add_argument("--run", action="store_true", help="run them")
    args = parser.parse_args(argv)
    try:
        files = input_files(args.paths, args.base)
    except ValueError as error:
        parser.error(str(error))
    except subprocess.CalledProcessError:
        parser.error(f"cannot diff against {args.base}; fetch it or pass file paths")
    if any(f in DART_GLOBAL for f in files):
        print("# pubspec or analysis options changed: every Dart test can be affected "
              "(make check, or rely on PR CI)", file=sys.stderr)
    commands = commands_for(files)
    if not commands:
        print("# no affected tests", file=sys.stderr)
        return 0
    if args.run:
        try:
            return run(commands)
        except (RuntimeError, subprocess.CalledProcessError) as error:
            print(f"relevant-tests: Flutter setup failed: {error}", file=sys.stderr)
            return 1
    for command in commands:
        print(command)
    return 0


if __name__ == "__main__":
    sys.exit(main())
