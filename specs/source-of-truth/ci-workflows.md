# CI & Workflows

Absorbed from `.github/workflows/` @ 103a70f:

- `ci-checks.yml` — analyze, localization check, unit tests, coverage.
- `build-web.yml` / `build-android.yml` — platform builds; Android emulator jobs pinned to `ubuntu-24.04` ahead of the Ubuntu 26 migration (#200/#189).
- `validation.yml` — validation gates; `release-gated.yml` — release workflow (#145).
- For matching non-pull-request changes, Firestore rules are validated when the `FIRESTORE_RULES_B64` secret is configured; an unset secret emits a warning and skips validation. Rules themselves remain deliberately untracked (#165/#185).
- Duplicate-run avoidance: `scripts/ci/already_tested.sh` skips push-to-`main` runs of `ci-checks.yml` and `validation.yml` only when the pushed commit tree equals a merged PR head tree with a green run of the same workflow; builds still run on push (release artifacts). Workflows use per-PR concurrency with cancel-in-progress; `ci-checks.yml` path-filters PRs inside its gate job so its checks always report.
- Default-branch ruleset requires PRs (rebase only), linear history, up-to-date branches and checks `Decide whether to run CI`, `Check & Test`, `Detect changed areas`, `Web smoke test`, `Android smoke test`.

## Firebase Hosting

`firebase-hosting.yml` builds the web app with `--dart-define=FLAVOR=production`
(web builds cannot pass `--flavor`; `Config.environment` falls back to `FLAVOR`)
and deploys to Firebase Hosting site `my-foodsavr-store`
(web app `1:514586238925:web:e562b8b85d97417f83ae84`). Pushes to `main` and
manual runs deploy live; same-repo PRs get a 7-day preview channel. Missing
`FIREBASE_SERVICE_ACCOUNT_MY_FOODSAVR_STORE` or `FIREBASE_WEB_OPTIONS_B64`
skips the deploy with a warning. `RECAPTCHA_V3_SITE_KEY` and `WEB_ENV_B64` are
optional; `firebase_options.dart` stays untracked until App Check is enforced.
`WEB_ENV_B64` becomes `assets/.env`, which Hosting serves publicly.
