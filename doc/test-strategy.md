# Test Strategy

This document defines the evaluation and validation strategy for foodsavr, tracked in the validation epic (#158). It implements the project policy: **integration tests are the default; unit tests only where they are a better fit.**

## Test pyramid

| Layer | Tool | Scope | When it runs |
| :--- | :--- | :--- | :--- |
| Static analysis | `flutter analyze`, Copilot, Qodo, CodeRabbit | Lint, architecture, review | Every PR |
| Unit | `flutter test test/` | Models, services, validation logic — pure Dart, no Firebase | Every change to `lib/`, `test/` |
| Smoke (web) | Playwright (`test/e2e/tests/*.smoke.spec.ts`) | App boots, landing renders, no console errors | Web build affected |
| Smoke (Android) | `adb install` + launch on API 34 emulator | APK installs, main activity resumes in foreground, no fatal crash | Android build affected |
| Integration (Android) | `flutter test integration_test` on emulator + Firebase emulators | Full app flows on device | Android/integration paths affected |
| Integration (web) | Playwright (`test/e2e/tests/*.spec.ts`) | Auth, inventory/shopping-list CRUD, transfers, modals | Web paths affected |
| Firebase emulator tests | Firestore emulator + Auth emulator | CRUD against emulators (permissive rules override in CI; real security-rules validation is tracked separately) | `lib/`, `integration_test/**` affected |

## Unit vs integration decision rule

Write a **unit test** when the logic under test:
- is pure Dart (models, computed properties, validation, serialization)
- has no Firebase/UI dependency
- needs exhaustive edge-case coverage

Write an **integration test** when the behavior:
- spans services + repositories + Firestore
- depends on auth state or security rules
- is a user flow (view interaction, navigation, forms)

If an existing unit test mocks more than one repository/service boundary, it should be migrated to the integration suite.

## CI wiring

- `.github/workflows/ci-checks.yml` — format, analyze, localization, unit tests, coverage (existing).
- `.github/workflows/validation.yml` — path-filtered smoke, Android integration, and Playwright E2E jobs via `dorny/paths-filter`.
- Playwright lives in `test/e2e/` (`npm ci && npx playwright test`); smoke specs use the `.smoke.spec.ts` suffix and run in the `smoke` project.
- Firebase emulators must be running for integration and E2E suites (`make start-firebase-emulators` locally; started in CI jobs).

## Known flakiness

- GoRouter sequential test isolation (`backlog/gorouter-test-isolation.md`): router widget tests fail when run sequentially due to restoration state. Affected specs must be isolated or the restoration issue fixed; do not add retries as a workaround for this known cause.
- Emulator startup races: CI jobs wait for the emulator UI port (4000) before proceeding.

## Release gating

The release workflow must not run unless the validation matrix passed for the changed platform(s). See the release workflow issue (#145) and the deployment epic. App Distribution/Codemagic publish only after all required checks are green.

## Device farm / cloud testing

- Firebase Test Lab is **deprecated** (shutdown Sept 30, 2027); plan migration to Google Cloud Developer Device Platform.
- Use Patrol for native interactions (permission prompts, WebViews) not reachable from plain `integration_test`.
- Cost strategy: 1–2 representative devices per PR, wide matrix nightly/pre-release.
