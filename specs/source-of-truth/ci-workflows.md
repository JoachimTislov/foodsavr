# CI & Workflows

Absorbed from `.github/workflows/` @ 103a70f:

- `ci-checks.yml` — analyze, localization check, unit tests (app tests with `flutter test`, selected `packages/foodsavr_core` tests with `dart test` in the package, both through `scripts/ci/run_tests.dart`; a broken package test fails `Check & Test`), coverage (scoped to Dart/Flutter/package paths; runs strictly on PRs to `develop` and pushes to release branches `nightly`/`beta`/`stable`/`release`, not on `develop` pushes).
- `build-web.yml` / `build-android.yml` — platform release-artifact builds on `push` to release branches `nightly`/`beta`/`stable`/`release` (and `workflow_dispatch`), sharing `.github/actions/setup-flutter-app`; Android emulator jobs pinned to `ubuntu-24.04` ahead of the Ubuntu 26 migration (#200/#189).
- `docs-pages.yml` — strict MkDocs build and local navigation/asset validation on documentation PRs to `develop` and pushes to `nightly`/`beta`/`stable`/`release`; `release` promotions publish the vision, canonical spec, and project docs to GitHub Pages. This is the sole Pages deployment owner; `build-web.yml` retains Flutter build artifacts without deploying them.
- `validation.yml` — expensive change-gated validation using `scripts/ci/dep_impact.py` for Dependabot bumps and grouping Web smoke + Playwright E2E (`Web smoke test`) and Android smoke + integration tests (`Android smoke test`) into single setup/emulator runs, plus non-fork Firestore rules; gated on `merge/auto` for PRs to `develop` and runs on pushes to release branches `nightly`/`beta`/`stable`/`release` (not on `develop` pushes; ADR 0007). `release-gated.yml` — release candidate workflow on `release` pushes (#145). `dependency-review.yml` runs on dependency manifest/lockfile PRs only.
- For matching pushes or non-fork `merge/auto` PRs, Firestore rules are validated when the `FIRESTORE_RULES_B64` secret is configured; an unset secret emits a warning and skips validation. Rules themselves remain deliberately untracked (#165/#185).
- Duplicate-run avoidance: `scripts/ci/already_tested.sh` skips push runs of `ci-checks.yml` and `validation.yml` when the exact SHA already succeeded (e.g., fast-forward promotion between release branches) or when the pushed commit tree equals a merged PR head tree with a green run of the same workflow; builds still run on release-branch pushes (release artifacts). Workflows use per-PR concurrency with cancel-in-progress; `ci-checks.yml` path-filters PRs inside its gate job so its checks always report. On a PR synchronize (for example a rebase), the same script also skips when the previous head had a green run of the workflow and the old-to-new tree diff touches nothing in the workflow scope; Dependabot PR runs are not cancelled by their own rebases so the previous run finishes first. The merge gate holds only in-scope merges while another PR validates.
- `merge-gate.yml` — integrates PRs labeled `merge/auto` into `develop` one at a time: waits for `Detect changed areas` (`Validation`) and merges via `--rebase` when up to date with every head check green, otherwise rebases the oldest `BEHIND` PR (`@dependabot rebase` for Dependabot); runs as `MERGE_GATE_TOKEN` (ADR 0006, ADR 0007).
- `promote.yml` — periodic and manual (`workflow_dispatch`) fast-forward promotion along the linear release pipeline (`develop` -> `nightly` daily `0 4 * * *` UTC, `nightly` -> `beta` weekly Mondays `0 5 * * 1` UTC, `beta` -> `stable` -> `release` biweekly 1st & 15th `0 6 1,15 * *` UTC) via `scripts/github/promote_release.py` using `MERGE_GATE_TOKEN`, triggering release-branch checks and `release` deployment workflows without creating merge commits (ADR 0007).
- `agent-review.yml` — classifies non-draft, same-repository PRs (`opened`, `ready_for_review`, `synchronize`, `reopened`, and `workflow_dispatch`) via `scripts/github/pr_review.py`, stages `.agents/state/pr-<N>.json` and `.md`, executes `integrate-pr.json` at the required adaptive review tier (`fast`, `balanced`, `deep`, or `human` advisory; `exempt` skips model invocation), records decisions on the `agent-review-history` branch, and posts a head-bound attestation comment (`<!-- agent-review: ... -->`).
- `agent-incident.yml` — owner-triggered (`workflow_dispatch`): runs `pr_review.py bisect-learn` on the default branch and persists the escalating incident to the `agent-review-history` branch.
- `scripts/ci/local_ci.py` — local mirror of CI for changed areas (diffing against `origin/develop` by default), run by the `.githooks/pre-push` hook (`make hooks`); `agent-system.yml` and `docs-pages.yml` run its `agents` and `docs` groups, and its `dart` group is kept equal to `ci-checks.yml` at CI's pinned Flutter version.
- Default-branch (`develop`) ruleset requires PRs (rebase only), linear history, up-to-date branches, and cheap checks `Decide whether to run CI` and `Check & Test`. Release branches (`nightly`, `beta`, `stable`, `release`) enforce linear history, no force pushes, no deletion, and fast-forward-only promotion.

Workflow secrets fail gracefully. Missing `FIREBASE_OPTIONS_B64` creates a
compile-only placeholder and records a warning instead of producing an opaque
base64 or file error. Missing `CODECOV_TOKEN` skips the optional coverage upload
with a warning. Missing Firestore rules already skips that optional validation
with a warning. Release and Drive credentials remain explicit prerequisites;
their jobs stop with a named missing-secret error before attempting a publish.

## Firebase Hosting

`firebase-hosting.yml` first resolves an environment (flavor) from `deploy/instance.yaml`
(`levels env`; see [deployment-levels.md](deployment-levels.md)): pushes to `release` use `production`;
`workflow_dispatch` input `environment` (default `auto`: `staging` for previews when the manifest
declares a cloud staging environment, else `production`). It builds the web app with
`--dart-define=FLAVOR=<environment>` (web builds cannot pass `--flavor`; `Config.environment`
falls back to `FLAVOR`) and deploys to that environment's Firebase project, web app and Hosting site
from the manifest (production: `my-foodsavr-store`). All deployments are
skipped unless the owner explicitly sets repository variable
`FIREBASE_HOSTING_ENABLED=true`. Keep it unset while Hosting is disabled;
merging the workflow does not authorize enabling it. Once enabled, pushes
to `release` deploy live;
previews are manual only (`workflow_dispatch`, target `preview`: channel named after the branch,
expiring after input `expires` (default `4h`), linked on its PR; target `live` deploys live). It signs in
keylessly (Workload Identity Federation) and generates the web-only
`firebase_options.dart` from the Firebase API at build time
(`scripts/web/write_web_config.py`). Missing `GCP_WORKLOAD_IDENTITY_PROVIDER` or
`GCP_DEPLOY_SERVICE_ACCOUNT` Actions variables (suffixed per non-production environment, e.g.
`_STAGING`) skip the deploy with a warning.
`RECAPTCHA_ENTERPRISE_SITE_KEY`, `ANDROID_APK_URL` (`/android` redirect) and the
`WEB_ENV_B64` secret are optional.
Before each deploy `scripts/web/hosting_storage_guard.py` flags builds over 5 GB and keeps Hosting storage
in budget: above 8 GB it deletes preview channels oldest-first and skips a
preview that would not fit; a live deploy may also delete live versions older
than the 3 latest to stay under 10 GB, and fails only if that is not enough.
`WEB_ENV_B64` becomes `assets/.env`, which Hosting serves publicly.

## Cloud infrastructure

`infra/terraform` manages the GitHub deploy identity, web API key referrer
restriction and App Check (reCAPTCHA Enterprise; enforcement `UNENFORCED` until
every client is registered) for one environment, plus a monthly budget when the
environment is on `firebase-blaze`. Apply with `ENV=<flavor> scripts/infra/apply.sh`
(owner gcloud login; values from `deploy/instance.yaml`). Existing GCS state
is retained; fresh Spark instances use private local state under
`.deployment-state/<project>/<flavor>`, which the owner must back up.
It also sets the Actions variables when `gh` is logged in.
Newcomers start with `scripts/infra/bootstrap.sh`
(prerequisites, human-only steps, then `apply.sh`).

## Deployment level

`deployment-level.yml` (ADR 0005): on pull requests touching manifests,
deployment tooling, infrastructure, or Hosting workflows, it formats,
analyzes, and tests the package, validates manifests, and tests bootstrap
state selection and API-key discovery offline. Daily (cron) and on
`workflow_dispatch` it polls every cloud environment (matrix;
state per environment in `actions/cache`) and keeps one open issue labelled
`deployment-level` updated while any recommends `warn` or `promote`. Recommend-only:
there is no apply job; missing Workload Identity variables skip polling with a warning.

## Android test APK for manual testing

For a direct test install, use the manually dispatched `Android test APK to
Google Drive` workflow. It builds the production flavor against the existing
Firebase test project and uploads the APK directly to Drive. It does not upload
an Actions artifact, publish to Play, or write an APK into the repository. The
automatic Android delivery workflow and Play internal deployment have been
removed.
The workflow requires `GOOGLE_DRIVE_FOLDER_ID` and
`GOOGLE_DRIVE_OAUTH_JSON`. It uses the existing `FIREBASE_OPTIONS_B64` Actions
secret for the Firebase test project and derives the matching native Android
configuration from it. `ANDROID_ENV_B64` may provide the bundled runtime
configuration; when absent, the workflow uses non-secret API endpoint defaults.
The Drive job requires the Firebase secret because a compile-only placeholder
would not be a usable remote-backend APK. It uses the debug signing key
intended for direct test installation.

For one-time interactive setup, run `bash scripts/release/setup_drive_deployment.sh`.
It lists the available Drive folders and lets you select one, authorizes the
active gcloud account with Drive access, validates the grant, and provisions `GOOGLE_DRIVE_ACCOUNT`,
`GOOGLE_DRIVE_FOLDER_ID`, and `GOOGLE_DRIVE_OAUTH_JSON` through `gh secret set`.
For noninteractive use, pass the folder ID as the first argument or set
`GOOGLE_DRIVE_FOLDER_ID`.
If gcloud requires a custom OAuth client, set `GOOGLE_OAUTH_CLIENT_ID_FILE`.
The helper never writes credentials to the repository or prints the account.

The existing remote Firebase project is the test environment; a production
backend will be added later. Supply that existing project's files for
`com.foodsavr.app`. The Android flavor is named `production` because it uses
a remote backend, but that name doesn't make this a production deployment.
The development flavor still uses local Firebase emulators. No new Firebase
project or flavor is required for this testing pipeline.

### GitHub configuration

Set these repository secrets before enabling delivery. Base64 inputs must be
single-line encoded files, for example `base64 -w 0 <file>` on Linux.

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_B64` | Existing upload keystore, base64 encoded. |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password. |
| `ANDROID_KEY_ALIAS` | Upload key alias. |
| `ANDROID_KEY_PASSWORD` | Upload key password. |
| `ANDROID_FIREBASE_OPTIONS_B64` | Matching test project's generated `firebase_options.dart`, base64 encoded. |
| `ANDROID_GOOGLE_SERVICES_B64` | Matching test project's `google-services.json` with `com.foodsavr.app`, base64 encoded. |
| `ANDROID_ENV_B64` | Runtime `assets/.env` configuration, base64 encoded. Its contents are bundled into the app; don't include server credentials. |
| `GOOGLE_DRIVE_FOLDER_ID` | Destination folder ID, not its full URL. |
| `GOOGLE_DRIVE_ACCOUNT` | The gcloud account authorized for Drive; used only during setup validation. |
| `GOOGLE_DRIVE_OAUTH_JSON` | OAuth JSON containing `client_id`, `client_secret`, and `refresh_token` for a user who can write to the folder. |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Play publishing service-account JSON with access to this app's testing releases. |

The existing `FIREBASE_OPTIONS_B64` secret remains in use for normal CI builds.
Drive authorization must allow file creation in the selected folder. Use a
durable OAuth grant with the Drive API enabled; the workflow refreshes access
tokens automatically. It preserves the folder's access settings and doesn't
make APKs public. Sign into that account on the phone to download them.

Create/configure the Play Console app for `com.foodsavr.app`, enable the Android
Publisher API, configure Play App Signing, and register internal testers. If
this is a new app, complete its initial Console setup and first release before
expecting API publishing to succeed. The upload key must match the app's
registered upload key. This workflow doesn't create the Play listing.

Android version codes use `ANDROID_VERSION_CODE_BASE` (a repository variable,
default `100000`) plus the parent Release workflow run number. Set the base
above previously published version codes when adopting this workflow; don't
lower it later. If only one upload fails, rerun failed jobs so it reuses the
existing artifact. Rerunning a completed Play upload with the same version code
isn't supported.

### Manual test readiness

Before installing the downloaded APK, configure the chosen Firebase test
project's Authentication providers, Firestore rules/indexes, and test users.
External grocery integrations also need working runtime configuration.
The workflow supplies files; it doesn't deploy those backend resources.

The remote-backend app uses Play Integrity for Firebase App Check. Register
the Play app-signing certificate and verify App Check for internal installs.
A sideloaded APK is signed with the upload key and may not meet the configured
Play Integrity policy. Verify that route in the existing Firebase test project
before relying on it for manual testing. Play and sideloaded APKs may
have different signing certificates; switching install sources can require
uninstalling the existing app, which removes its local data.

After delivery, open the Drive job's summary for **Download Android APK**.
For Play delivery, testers must join through the internal-testing opt-in link
configured in Play Console. Test login, inventory changes, and receipt scanning
against the chosen test backend; a green build doesn't verify those credentials
or external integrations.

### Emulator evidence

The Validation workflow's Android smoke job starts isolated Firebase emulators,
builds the development APK with `EMULATOR_HOST=10.0.2.2`, and records startup on
an Android virtual device. Its `android-visuals` artifact contains a screenshot,
startup video, and logs, retained for 14 days, including failure evidence when
available. These visuals show the development backend, not the remote test
project. Integration tests remain a separate Validation job.

For local manual testing, start Firebase emulators and use an Android virtual
device with:

```sh
make start-firebase-emulators
flutter run --flavor development --dart-define=EMULATOR_HOST=10.0.2.2
```

This requires a working Android SDK, accepted SDK licenses, a running virtual
device, Firebase CLI, resolved Flutter dependencies, and regenerated DI code.
When using the agent's device panel, launch and interact through its device
tools after building/installing the app.
