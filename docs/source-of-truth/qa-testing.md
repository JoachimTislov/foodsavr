# QA & Testing

Absorbed from `doc/test-strategy.md` and CI (@ 103a70f):

- Unit tests under `test/`, integration tests under `test_driver/`-backed `integration_test/`.
- CI runs analyze, localization check, unit tests, coverage, validation gates (`validation.yml`, `ci-checks.yml`).
- Validation/eval setup tracked by #158 (remaining: #166, #168).
- `foodsavr_core` is pure Dart and unit-testable without Firebase emulators.

## Verification loop (per ADR 0002)

The system shall behave as the intended usage induces: tests apply against the main entry points and core parts of the system, minimizing suite runtime.

- **Hash-based caching**: per-test input hashes (test file + transitive imports); a matching previously-green hash skips the test as cached-green.
- **Relational selection**: changed files map to the tests that relate to them through import relations; only the affected slice runs.
- **Core workflow pinning**: login (`test/services/auth_service_test.dart`, `test/router_auth_flow_test.dart`), receipt scanning (`test/services/receipt_ingestion_service_test.dart`), inventory synchronization (`test/services/collection_service_integration_test.dart`, `integration_test/`), and domain/model invariants always run on CI triggers.
- **Escape hatch**: full suite via `workflow_dispatch` or whenever `scripts/ci/select_tests.dart` or its relation map changes.
