# Agent Instructions

## User preferences

- Be minimal. Write nothing beyond what the user strictly needs to know.
- Always log events (what was changed, committed, pushed, replied) when doing repo work.

## Event log

| Date (UTC) | Event |
|---|---|
| 2026-10-03 | PR #77 (`docs/update-readme-and-license`): verified mergeable, all checks green; commit `09f2355` fixed broken `CONTRIBUTING.md` link in `doc/introduction.md`; commit `docs(getting-started): add firebase login, npm prerequisite and PATH note` fixed 3 CodeRabbit findings; replied to all review threads. Merge blocked by sandbox (CLI/API/MCP all disallowed) — must be merged on GitHub. |
| 2026-10-03 | PR #170 (`vibe/ci-path-filters-71b359`): added CI path narrowing (`assets/translations/**`, `pubspec.lock`, `analysis_options.yaml`) and a `gate` job that skips push runs only for GitHub PR merge commits; fixed CodeRabbit/Copilot findings (`pubspec.lock` paths, PR-merge-only skip); replied to all threads. Draft, ready for re-review. |
