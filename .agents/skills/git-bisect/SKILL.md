---
name: git-bisect
description: Find the commit that introduced a regression with worktree-isolated git bisect. Use when a bug or performance drop appeared between two known commits and a tight red-capable reproducer exists.
metadata:
  audience: agent
---

# Git bisect

`scripts/bisect.py` bisects in a temporary detached worktree, so the caller's branch and uncommitted work are untouched. Stdlib only; `make bisect ARGS='...'` wraps it. `--help` lists every flag.

## When

Bisect only when the bug appeared between two known commits **and** a tight pass/fail reproducer exists ([diagnosing-bugs](../diagnosing-bugs/SKILL.md) Phase 1). Without a reproducer, build one first. Do not bisect a flaky signal: run the reproducer 3 times on each endpoint first.

## Run

1. Pick bounds: `--good` is a tag, merge-base or last known-green commit; `--bad` defaults to `HEAD`. Narrow with `--paths <path>...` when the suspect area is known.
2. Validate endpoints with `--verify-ends`, which checks that the good endpoint passes and the bad endpoint fails.
3. Automated (always when unattended):
   ```sh
   python3 scripts/bisect.py --good <rev> --verify-ends --json \
     --probe /abs/path/repro_test.dart:test/repro_test.dart \
     --setup 'dart run build_runner build' --timeout 600 \
     -- flutter test test/repro_test.dart
   ```
   - The check exits `0` good, `125` skip, any other code bad. Not-found/not-executable (`126`/`127`), timeouts, a failing `--setup` and a failing `pub get` skip, never a false bad.
   - `--probe SRC[:DEST]` copies an untracked reproducer into the worktree before each step and removes it afterwards: it does not exist in older commits otherwise.
   - `pubspec.yaml`/`pubspec.lock` changes trigger `flutter pub get` (binary from `scripts/ci/local_ci.py --flutter-bin`, override with `--flutter-bin`); the tree is reset between commits.
4. Human in the loop only with a TTY and a human present: `--interactive [--launch '<build/run cmd>']` prompts `good/bad/skip/abort`. It refuses to start without a TTY, so headless runs never block.

## Result

Exit `0` with a culprit, `1` with no single culprit, `2` on setup error, `130` on abort. The report (and `--json`) holds `first_bad`, `skipped`, `candidates`, `git show --stat` and `scripts/agents/agentctl trace <sha>` provenance (PR, issue, session).

- **Skipped or unbuildable commits**: when only skipped commits remain, the `candidates` bound the culprit. Fix the skip cause (`--setup`, narrower `--paths`) and rerun, or inspect the candidates by hand.
- **Flaky repro**: a wrong culprit usually means a flaky check; make the reproducer deterministic and rerun.
- Feed the culprit and its trace into the root-cause and regression-test phases of [diagnosing-bugs](../diagnosing-bugs/SKILL.md).

The worktree and bisect state are removed on exit, error, SIGINT and SIGTERM; `--keep-worktree` keeps it for debugging.
