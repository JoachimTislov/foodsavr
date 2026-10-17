# CI & Workflows

Absorbed from `.github/workflows/` @ 103a70f:

- `ci-checks.yml` — analyze, localization check, unit tests, coverage.
- `build-web.yml` / `build-android.yml` — platform builds; Android emulator jobs pinned to `ubuntu-24.04` ahead of the Ubuntu 26 migration (#200/#189).
- `validation.yml` — validation gates; `release-gated.yml` — release workflow (#145).
- Firestore rules validated in CI via `FIRESTORE_RULES_B64` secret; rules themselves deliberately untracked (#165/#185).
