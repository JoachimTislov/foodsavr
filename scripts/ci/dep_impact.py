#!/usr/bin/env python3
"""Classify Dependabot pubspec bumps by platform impact for CI gating."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

ANDROID_ONLY = frozenset({
    "google_mlkit_barcode_scanning",
    "google_mlkit_text_recognition",
})

WEB_ONLY = frozenset({
    "web",
})

PURE_DART = frozenset({
    "build_runner",
    "cupertino_icons",
    "crypto",
    "easy_localization",
    "easy_logger",
    "flutter_dotenv",
    "flutter_lints",
    "freezed",
    "freezed_annotation",
    "fuzzywuzzy",
    "get_it",
    "go_router_builder",
    "http",
    "injectable",
    "injectable_generator",
    "intl",
    "json_annotation",
    "json_serializable",
    "logger",
    "lints",
    "meta",
    "mocktail",
    "openfoodfacts",
    "path",
    "test",
    "vector_graphics",
    "vector_graphics_codec",
    "vector_graphics_compiler",
    "watch_it",
})

DEP_LINE_RE = re.compile(r"^[+-]  ([a-z0-9_]+):")


def git_pubspec_diff(base_ref: str) -> str:
    result = subprocess.run(
        ["git", "diff", "--unified=0", f"{base_ref}...HEAD", "--", "pubspec.yaml", "packages/*/pubspec.yaml"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(
            f"dep_impact: warning: git diff against {base_ref} failed ({result.stderr.strip()}); running all platforms",
            file=sys.stderr,
        )
        return ""
    return result.stdout


def extract_bumped_packages(diff_text: str) -> list[str]:
    packages: set[str] = set()
    for line in diff_text.splitlines():
        match = DEP_LINE_RE.match(line)
        if match:
            pkg = match.group(1)
            if pkg != "sdk":
                packages.add(pkg)
    return sorted(packages)


def classify_impact(event_name: str, pr_author: str, diff_text: str) -> tuple[bool, bool]:
    """Return (run_android, run_web) for the change."""
    if event_name != "pull_request" or pr_author != "dependabot[bot]":
        return True, True

    bumped = extract_bumped_packages(diff_text)
    if not bumped:
        return True, True

    run_android = False
    run_web = False
    for pkg in bumped:
        if pkg in PURE_DART:
            continue
        if pkg in ANDROID_ONLY:
            run_android = True
        elif pkg in WEB_ONLY:
            run_web = True
        else:
            run_android = True
            run_web = True
    return run_android, run_web


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default=f"origin/{os.environ.get('GITHUB_BASE_REF', 'main')}")
    args = parser.parse_args(argv)

    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    pr_author = os.environ.get("PR_AUTHOR", "")
    diff_text = git_pubspec_diff(args.base) if (event_name == "pull_request" and pr_author == "dependabot[bot]") else ""
    run_android, run_web = classify_impact(event_name, pr_author, diff_text)

    lines = [
        f"run_android={'true' if run_android else 'false'}",
        f"run_web={'true' if run_web else 'false'}",
    ]
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with Path(github_output).open("a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    for line in lines:
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
