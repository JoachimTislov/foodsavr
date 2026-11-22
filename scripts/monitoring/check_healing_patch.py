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


def validate_paths(paths: list[str]) -> tuple[bool, list[str]]:
    cleaned = [p.strip() for p in paths if p and p.strip()]
    if not cleaned:
        return False, ["no changed files in healing patch"]
    errors: list[str] = []
    for path in cleaned:
        ok, reason = is_path_allowed(path)
        if not ok:
            errors.append(reason)
    return len(errors) == 0, errors


def paths_from_patch_text(patch_text: str) -> list[str]:
    paths: list[str] = []
    for line in patch_text.splitlines():
        match = _DIFF_HEADER_RE.match(line)
        if match:
            a_path, b_path = match.group(1), match.group(2)
            paths.append(b_path)
            if a_path != b_path:
                paths.append(a_path)
    return sorted(set(paths))


def paths_from_git_cached(cwd: Path = ROOT) -> list[str]:
    out = subprocess.check_output(
        ["git", "diff", "--cached", "--name-only"],
        cwd=cwd,
        text=True,
    )
    return [line.strip() for line in out.splitlines() if line.strip()]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--git-cached", action="store_true", help="Inspect staged git index paths")
    parser.add_argument("--diff-file", default=None, help="Inspect a unified diff patch file")
    parser.add_argument("files", nargs="*", help="Explicit file paths to check")
    args = parser.parse_args(argv)

    if args.git_cached:
        paths = paths_from_git_cached()
    elif args.diff_file:
        paths = paths_from_patch_text(Path(args.diff_file).read_text(encoding="utf-8"))
    else:
        paths = list(args.files)

    ok, errors = validate_paths(paths)
    print(json.dumps({"ok": ok, "files": paths, "errors": errors}, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
