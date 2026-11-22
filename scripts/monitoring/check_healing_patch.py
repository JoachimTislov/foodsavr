#!/usr/bin/env python3
"""Enforce two-way-door path guardrails for bounded autonomous healing patches."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]

ALLOWED_PREFIXES = (
    "lib/",
    "web/",
    "test/",
    "assets/translations/",
    "packages/foodsavr_core/lib/",
    "packages/foodsavr_core/test/",
)

BLOCKED_PREFIXES = (
    ".github/",
    ".agents/",
    ".claude/",
    ".gemini/",
    "infra/",
    "firestore-rules/",
    "firestore.rules",
    "scripts/",
    "specs/",
    ".githooks/",
    "Makefile",
    "deploy/",
    "pubspec.yaml",
    "pubspec.lock",
    "analysis_options.yaml",
    "android/",
)

_DIFF_HEADER_RE = re.compile(r"^diff --git a/(.+?) b/(.+?)$")
_DIFF_MODE_RE = re.compile(r"^(?:new file mode|old mode|new mode|deleted file mode)\s+([0-7]{6})$")
_DIFF_INDEX_MODE_RE = re.compile(r"^index\s+[0-9a-f]+\.\.[0-9a-f]+\s+([0-7]{6})$")
DISALLOWED_MODES = {
    "120000": "symlink",
    "160000": "submodule/gitlink",
}


def is_path_allowed(raw_path: str) -> tuple[bool, str]:
    path = raw_path.strip().replace("\\", "/")
    if not path:
        return False, "empty path"
    if path.startswith("/"):
        return False, f"absolute path rejected: {path}"
    parts = PurePosixPath(path).parts
    if ".." in parts:
        return False, f"path traversal rejected: {path}"
    normalized = "/".join(parts)
    for blocked in BLOCKED_PREFIXES:
        if normalized == blocked or normalized.startswith(blocked):
            return False, f"blocked path {normalized!r} (matches {blocked!r})"
    if any(normalized.startswith(prefix) for prefix in ALLOWED_PREFIXES):
        return True, "allowed"
    return False, f"path {normalized!r} outside two-way-door healing allowlist"


def validate_paths(paths: list[str], mode_errors: list[str] | None = None) -> tuple[bool, list[str]]:
    cleaned = [p.strip() for p in paths if p and p.strip()]
    errors: list[str] = list(mode_errors or [])
    if not cleaned:
        errors.append("no changed files in healing patch")
        return False, errors
    for path in cleaned:
        ok, reason = is_path_allowed(path)
        if not ok:
            errors.append(reason)
    return len(errors) == 0, errors


def inspect_patch_text(patch_text: str) -> tuple[list[str], list[str]]:
    paths: list[str] = []
    mode_errors: list[str] = []
    current_path = "<unknown>"
    for line in patch_text.splitlines():
        match = _DIFF_HEADER_RE.match(line)
        if match:
            a_path, b_path = match.group(1), match.group(2)
            current_path = b_path
            paths.append(b_path)
            if a_path != b_path:
                paths.append(a_path)
            continue
        mode_match = _DIFF_MODE_RE.match(line) or _DIFF_INDEX_MODE_RE.match(line)
        if mode_match:
            mode = mode_match.group(1)
            if mode in DISALLOWED_MODES:
                mode_errors.append(f"disallowed git mode {mode} ({DISALLOWED_MODES[mode]}) on {current_path!r}")
    return sorted(set(paths)), sorted(set(mode_errors))


def paths_from_patch_text(patch_text: str) -> list[str]:
    paths, _ = inspect_patch_text(patch_text)
    return paths


def parse_git_raw_diff(raw_output: str) -> tuple[list[str], list[str]]:
    """Parse `git diff --cached --raw` lines for both file paths and disallowed modes."""
    paths: list[str] = []
    mode_errors: list[str] = []
    for line in raw_output.splitlines():
        if not line.startswith(":"):
            continue
        header, _, path_part = line[1:].partition("\t")
        fields = header.split()
        if len(fields) < 5 or not path_part:
            continue
        old_mode, new_mode = fields[0], fields[1]
        entry_paths = [p.strip() for p in path_part.split("\t") if p.strip()]
        paths.extend(entry_paths)
        target_label = entry_paths[-1] if entry_paths else path_part
        for mode in (old_mode, new_mode):
            if mode in DISALLOWED_MODES:
                mode_errors.append(f"disallowed git mode {mode} ({DISALLOWED_MODES[mode]}) on {target_label!r}")
    return sorted(set(paths)), sorted(set(mode_errors))


def inspect_git_cached(cwd: Path = ROOT) -> tuple[list[str], list[str]]:
    out = subprocess.check_output(
        ["git", "diff", "--cached", "--raw"],
        cwd=cwd,
        text=True,
    )
    return parse_git_raw_diff(out)


def paths_from_git_cached(cwd: Path = ROOT) -> list[str]:
    paths, _ = inspect_git_cached(cwd=cwd)
    return paths


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--git-cached", action="store_true", help="Inspect staged git index paths")
    parser.add_argument("--diff-file", default=None, help="Inspect a unified diff patch file")
    parser.add_argument("files", nargs="*", help="Explicit file paths to check")
    args = parser.parse_args(argv)

    mode_errors: list[str] = []
    if args.git_cached:
        paths, mode_errors = inspect_git_cached()
    elif args.diff_file:
        paths, mode_errors = inspect_patch_text(Path(args.diff_file).read_text(encoding="utf-8"))
    else:
        paths = list(args.files)

    ok, errors = validate_paths(paths, mode_errors=mode_errors)
    print(json.dumps({"ok": ok, "files": paths, "errors": errors}, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
