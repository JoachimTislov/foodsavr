#!/usr/bin/env python3
"""Fail unless HEAD contains the latest tip of the PR base branch.

Usage: check_pr_base.py [base-branch]   (default: remote default branch)
"""
import subprocess
import sys


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *args], capture_output=True, text=True)


def default_branch() -> str:
    out = git("ls-remote", "--symref", "origin", "HEAD").stdout
    for line in out.splitlines():
        if line.startswith("ref: refs/heads/"):
            return line.split()[1].removeprefix("refs/heads/")
    return "main"


def main(argv: list[str]) -> int:
    base = argv[0] if argv else default_branch()
    fetched = git("fetch", "--quiet", "origin", base)
    if fetched.returncode != 0:
        print(f"check_pr_base: cannot fetch origin/{base}: {fetched.stderr.strip()}", file=sys.stderr)
        return 2
    if git("merge-base", "--is-ancestor", f"origin/{base}", "HEAD").returncode == 0:
        return 0
    behind = git("rev-list", "--count", f"HEAD..origin/{base}").stdout.strip()
    print(
        f"check_pr_base: branch is {behind} commit(s) behind origin/{base}. "
        f"Run `git rebase origin/{base}` (or merge) before opening the PR.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
