# Agent Instructions

## User preferences

- Be minimal. Write nothing beyond what the user strictly needs to know.
- Always log events (what was changed, committed, pushed, replied) when doing repo work.

## Event log

| Date (UTC) | Event |
|---|---|
| 2026-10-05 | PR #178 for #164: dropped `continue-on-error` from the Android integration CI job (suite green on the three most recent non-skipped runs) making it a blocking gate; documented gate status in test-strategy; updated issues #164 and #158 epic checkboxes. |
| 2026-10-05 | PR #177 review round 1 wrap-up: posted in-thread reply on the remaining CodeRabbit comment (transfer-view location assertion — skipped with reason, view uses static demo locations); all 4 threads now resolved or replied. |
| 2026-10-05 | PR #177 review: fixed 3 CodeRabbit findings (normalize emulator host env vars; suite-owned-only cleanup; assert list/DELETE responses) and skipped 1 with reason (transfer view uses static demo locations, not Firestore collections); replied on the PR; second push ce5769d. |
| 2026-10-05 | PR2 for #163: added core-flow Playwright specs (`navigation.spec.ts`, `collections.spec.ts`, `transfers.spec.ts`) with Firestore-emulator REST seeding helpers; fixed flaky landing smoke (auto-login race vs. semantics-node detach — dispatchEvent click + dashboard fallback); updated test-strategy doc. All 10 specs green locally. |
| 2026-10-05 | PR #176 merged (smoke suites for web and Android, closes #162). Prior to merge: Codecov `Check & Test` failed once on a transient TLS handshake; retriggered green; addressed all CodeRabbit findings (bounded/retried adb waits, one-line pidof poll, console-error assertions, gfxinfo frame-render check, smoke gates on heavier suites). |
| 2026-10-04 | PR #176 review (round 2): fixed CodeRabbit major finding — emulator runner runs each `script:` line in a separate `sh -c`, so the multiline `pidof` poll collapsed to a one-liner (97c0629); replied and thread resolved. |
| 2026-10-04 | PR #176 review: fixed 2 CodeRabbit findings in `android-smoke` (bounded 30s `pidof` poll replacing unbounded wait loop; 10x retry on resumed-activity/window-focus checks + 5s delayed logcat snapshot); replied to both threads and marked resolved. |
| 2026-10-03 | PR #77 (`docs/update-readme-and-license`): verified mergeable, all checks green; commit `09f2355` fixed broken `CONTRIBUTING.md` link in `doc/introduction.md`; commit `docs(getting-started): add firebase login, npm prerequisite and PATH note` fixed 3 CodeRabbit findings; replied to all review threads. Merge blocked by sandbox (CLI/API/MCP all disallowed) — must be merged on GitHub. |
| 2026-10-03 | PR #170 (`vibe/ci-path-filters-71b359`): added CI path narrowing (`assets/translations/**`, `pubspec.lock`, `analysis_options.yaml`) and a `gate` job that skips push runs only for GitHub PR merge commits; fixed CodeRabbit/Copilot findings (`pubspec.lock` paths, PR-merge-only skip); replied to all threads. Draft, ready for re-review. |
