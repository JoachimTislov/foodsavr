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
| Integration (web) | Playwright (`test/e2e/tests/*.spec.ts`) | Tab navigation, inventory/shopping-list creation dialogs, transfer view (Firestore-emulator-seeded inventories) | Web paths affected |
| Firebase emulator tests | Firestore emulator + Auth emulator | CRUD against emulators (permissive rules override in CI app suites) | `lib/`, `integration_test/**` affected |
| Firestore security rules | `@firebase/rules-unit-testing` (`firestore-rules/`) | Owner-based access on `products` (personal and admin-managed global), `collections`, `users/{uid}/**`, `owners/{uid}/rawEvents` (create-only), `runtime_errors` (create-only), `roles`, and default deny; app query shapes | `firestore-rules/**` or `firestore.rules` affected; the suite tests the tracked `firestore.rules` (ADR 0010); set `FIRESTORE_RULES_PATH` or `FIRESTORE_EMULATOR_HOST` (default `localhost:8080`) to override |

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

- `.github/workflows/_reusable-dart-checks.yml` (verdict: `Check & Test` in `pull-request.yml`) — format, analyze, localization, unit tests; relational selection on PRs, full suite with coverage on `daily` and dispatch.
- `.github/workflows/_reusable-web-playwright.yml` (Validation in `pull-request.yml`) — Playwright smoke on PRs (started by `merge/auto`); desktop and mobile E2E on `daily` and dispatch ([tiers](../specs/ci-workflows.md)). The Android smoke and integration job (`reactivecircus/android-emulator-runner`, API 34, KVM on `ubuntu-24.04`) runs only on manual dispatch (`make validate`).
- Playwright lives in `test/e2e/` (`npm ci && npx playwright test`); smoke specs use the `.smoke.spec.ts` suffix and run in the `smoke` project.
- `.github/workflows/release.yml` builds and uploads the Flutter `web-build` artifact on release pushes. `pull-request.yml` validates the documentation build and local links on PRs; `release.yml` publishes the vision, spec, and docs to GitHub Pages on `stable`.

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
