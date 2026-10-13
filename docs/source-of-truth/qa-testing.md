# QA & Testing

Absorbed from `doc/test-strategy.md` and CI (@ 103a70f):

- Unit tests under `test/`, integration tests under `integration_test/`, driver under `test_driver/`.
- CI runs analyze, localization check, unit tests, coverage, validation gates (`validation.yml`, `ci-checks.yml`).
- Validation/eval setup tracked by #158 (remaining: #166, #168).
- `foodsavr_core` is pure Dart and unit-testable without Firebase emulators.
