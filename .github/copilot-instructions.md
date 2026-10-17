# FoodSavr Copilot Instructions

FoodSavr is a Flutter application for inventory, expiration tracking, meal
planning, recipes, and reducing food waste.

## Repository map

- `lib/`: Flutter application code, organized as views/widgets, services,
  repository interfaces and implementations, models, utilities, and DI.
- `test/` and `integration_test/`: Dart unit, widget, and integration tests.
- `firestore-rules/`: Firestore security-rule tests.
- `assets/translations/`: `easy_localization` translation files.
- `scripts/`: Dart-only project tooling.
- `doc/`, `docs/`, `README.md`, `TODO.md`, and `backlog/`: project
  documentation and work tracking.
- `.github/workflows/`: CI and release workflows.

## Engineering rules

- Keep the three tiers separated: views/widgets -> services -> repositories
  through interfaces. Models hold domain and serialization logic.
- Use GetIt (`getIt<T>()`) for dependencies. Do not instantiate services or
  repositories in widgets.
- Keep business logic out of widget `build` methods and private view helpers.
- Keep one widget per file. Lightweight forms use a static `show()` method and
  `showModalBottomSheet`; use routes for complex screens.
- Use localization keys and validate them with `make locale-check`; use
  `make locale-clean` only when removing confirmed unused keys.
- Use Firebase emulators for development and tests. Never add production
  credentials or secrets.
- Use Dart scripts only. Keep comments, logs, and documentation minimal and
  professional; do not add emojis.
- Preserve Firestore ownership and admin-registry authorization invariants.
  Rules changes require `make rules-test` with emulators.

## Required commands

- `make deps`: fetch Flutter dependencies.
- `make check`: analyze, test, localization-check, fix, and format; required
  before every commit.
- `make rules-test`: run Firestore rules tests with emulators.
- `make worktree name=<issue-or-branch>`: create an isolated source worktree.
- `make push`: preflight, check, and push the current branch.
- `make resolve-comments`: start the repository's PR review-resolution flow.

## Autonomous development loop

1. Run `gh pr list` — fix or answer open PRs first, using the
   `make resolve-comments` flow.
2. Run `gh issue list` — pick the highest-priority open issue.
3. If no issues remain, create issues from `TODO.md` or `backlog/` before
   working on them.
4. For each task, run `make worktree` and `make task`, implement the change,
   run `make check`, commit, push, open a PR, monitor CI, fix failures, respond
   to reviews, and repeat until green.
5. Inspect the PR file list. If it contains application source code, keep
   auto-merge disabled and run `gh pr edit --add-reviewer JoachimTislov` to
   request review from JoachimTislov. Otherwise, after all checks relevant to
   the changed paths are green, enable auto-merge with
   `gh pr merge --auto --rebase`. Update stale branches with
   `gh pr update-branch --rebase`; never update a PR branch by creating a
   merge commit.
6. Append one row per action to the event log in `AGENTS.md`.

The `PR autonomy` workflow performs step 5 automatically: it requests
`JoachimTislov` review for source changes and enables rebase-only auto-merge for
non-source changes. Repository rulesets remain the final enforcement layer.

## Merge policy

When CI is green, enable auto-merge for documentation, configuration, and
ruleset-only pull requests. Do not auto-merge a pull request that changes
application source code, including files under `lib/`, `test/`,
`integration_test/`, or platform source directories.

Before auto-merging, wait for every workflow check relevant to the changed
paths to pass; skipped unrelated jobs do not block the PR. For any PR that
touches application source code, do not enable auto-merge and request review
from `JoachimTislov` with `gh pr edit --add-reviewer JoachimTislov`.
