# FoodSavr - Guidelines

Project architecture, principles, and rules for `foodsavr` (Flutter SDK >=3.32.0).

## Stack & Architecture
- **Tech Stack**: Dart, Firebase (Auth/Firestore), GetIt (DI), logger, easy_localization.
- **Pattern**: 3-tier Layered Architecture
- **Core Principles**: Interface-based data access, DI for all dependencies, Emulator-driven dev.
- **Firestore Transaction**: Don't modify application state inside transactions; return data and update state after transaction completes to avoid UI inconsistencies.

## 2. Standards
- **Widget Rules**: **One widget per file**; no private builders (e.g., `_buildX()`) in views; centralize duplicate logic and markup.
- **Strict Separation**: Business logic **MUST** reside in models or services. **ZERO** business logic in widget build methods or private view helpers.
- **Lightweight Forms as Bottom Sheets**: Simple create/edit forms (e.g., collection form, product picker) should use `showModalBottomSheet` with a static `show()` method instead of full-screen route navigation. Reserve full routes for complex views.
- **No Python Scripts**: Use Dart scripts in `tool/` for any project tooling. Do not use Python.
- **Professional Output**: Keep comments and console output strictly minimal and professional. Do not use emojis or icons.

## Commands
- `make push`: Push to remote repository
- `make deps`: Fetch dependencies.
- `make check`: Run full suite (analyze, format, test). **Required before commit**.
- `make locale-check`: Validate all localization keys are present and used.
- `make locale-clean`: Remove all unused localization keys from JSON files.
- `make generate-locales`: Generate stubs for missing localization keys.

## 4. **Workflow**:
- **Meta-Task Branch**: Reserve the main working branch (default folder) for "meta" tasks (agents, documentation, research, system-level updates). All source code modifications must be made in separate Git worktrees.
- **Task Ordering**: Prioritize tasks in the following order: (1) handle existing PRs, (2) handle open issues, (3) create new issues systematically from the `TODO.md` / TODO folder backlog.
- **TODO Prioritization**: TODOs from local backlog files should only be tackled when there are no open issues and no open PRs available.
- **Task Completion**: After each completed task (or tight related batch), commit and push immediately.
- **Commit Message**: Use clear descriptive messages; prefer Conventional Commits (e.g., `fix(router): handle auth redirect`). **All formatting and linting changes must be included in your main feature/fix commit.** Do not create separate "format" commits. Always include `Co-authored-by: gemini@noreply.github.com` at the bottom of the commit message.
- **Starting Tasks**: Always start new tasks by running `make task msg="your task description"`. This automatically injects `INDEX.md` to map out the strategy before the agent begins file discovery.
- **Execution Loop**: Gather context (code/tests/PR comments/docs/rules/skills), check for missing context, implement minimal fix, run `make check`, add/update tests, run `make check` until green, run `make push`; if `make check` fails two times in a row, STOP and ask the instructor for guidance; if `make push` fails, fix and repeat from `make check`.
- **Introspection**: Re-evaluate context after each major step and keep only task-relevant information.
- **Future Improvement Logging**: Log follow-ups in `log/review-thread-followups.log` only when improvement is still needed (id, remaining gap, next action).
- **Implementation Rationale**: Record a concise reason (1-2 lines) for why the chosen approach was used.
- **Quality Risk Logging**: If quality may be weak at current stage, log task/risk/impact/follow-up in `log/implementation-risks.log`.
- **Resolved Comment Cleanup**: Remove stale comment references once high-quality, Effective Dart-aligned, non-fragile solutions are fully implemented.
- **GitHub Scripts**: Do not look up or pass PR numbers when using `make gh-*` commands or invoking PR-related sub-agents (like `comment-resolver`). These scripts automatically infer the correct PR from the current Git branch.
- **Style**: `snake_case` (files), `camelCase` (members), `_private`. Follow [Effective Dart](https://dart.dev/effective-dart/design).

## 5. Context Maintenance & Efficiency
- **Efficiency Goal**: Load **only** necessary context. If context becomes bloated or unstable, pause and ask the user to refine it.
- **Docs Maintenance**: Keep `doc/`, `README.md` and `INDEX.md` synchronized with the source code.
- **Context Poisoning**: If conflicting or obsolete instructions/rules degrade workflow efficiency, **STOP** and use `ask_user` to have the user resolve the conflict.
