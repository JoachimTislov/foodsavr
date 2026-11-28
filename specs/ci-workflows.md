# CI & Workflows

Six workflows in `.github/workflows/` cover every trigger (#496); `pull-request.yml` calls two reusable (`workflow_call`) workflows, `_reusable-dart-checks.yml` and `_reusable-web-playwright.yml`, which have no triggers of their own. Each multi-operation workflow gates every job on its own event and operation, so one event boots only the jobs it needs.

- `pull-request.yml` (`Pull Request`) — PR verification for PRs to `develop` (`opened`, `synchronize`, `reopened`, `ready_for_review`, `edited`, `labeled`), pushes to `daily`/`weekly`/`stable` and `merge-train/**`, the weekly agent-system schedule, and `workflow_dispatch` (`operation`: `all`, `checks`, `validation`). Its stages:
  - Stage 1, `Decide whether to run CI` (required check): posts the `Validation result` hold, then preflight (`scripts/ci/check_pr_base.py`, `agentctl check-pr` and `scripts/agents/check_logs.py`, and dependency review when dependency manifests change), then every suite decision. A failed preflight fails this required check, so the suites it skips never count as passing.
  - Stage 2, path-gated suites: `Check & Test` (required: the verdict of `Dart checks`, which calls `_reusable-dart-checks.yml` for format, analyze, localization, shape sync, and unit tests with `flutter test` and `packages/foodsavr_core` tests through `scripts/ci/run_tests.dart`; a called job reports as `<caller> / <job>`, so the verdict job keeps the ruleset's check name and runs with `always()` so a cancelled or failed suite never leaves it skipped), `Check release scripts`, `Agent system validation` (excluding `.agents/events/**`), `Build documentation`, and `Validate manifests and test levels CLI` (ADR 0005). The decisions come from `scripts/ci/local_ci.py --ci-filters`, the same group paths `make check` uses locally, so CI and the local mirror cannot select different suites.
  - Stage 3, Validation: `Detect changed areas` (the merge-queue check), `Web validation` (`_reusable-web-playwright.yml`: Playwright, and the non-fork `Firestore security rules`), and `Validation status (result)`. On PRs it starts when `merge/auto` is added; with repository variable `SELF_MANAGED_MERGE=true` it also starts automatically on every non-draft PR (including when a draft turns ready), so only drafts without the label hold. It runs on every push; `develop` pushes do not re-validate (ADR 0007). Android smoke + integration (`Android smoke test`, pinned to `ubuntu-24.04`) run only on `workflow_dispatch` (`make validate`), and `Validation result` succeeds without them.
- Suite tiers:

  | Trigger | Dart (`Dart checks / …`) | Web (`Web validation / …`) |
  |---|---|---|
  | `develop` PR, `merge-train/**` push | `Relational Dart suite` (ADR 0002), no coverage upload | `Web smoke test`: `smoke` project, path-gated (narrowed by `scripts/ci/dep_impact.py` for Dependabot bumps) |
  | `daily` push (nightly) | `Full Dart suite` with coverage, whatever the push touched | `Web full E2E`: `smoke`, `chromium` (desktop) and `mobile-chrome` (Pixel 7) projects, whatever the push touched |
  | `weekly`, `stable` push | path-gated; reused from a `Full Dart suite` push run of the same SHA, else run | path-gated; reused from a `Web full E2E` push run of the same SHA, else run |
  | `workflow_dispatch` | `Full Dart suite` (`operation`: `all`, `checks`) | `Web full E2E` (`operation`: `all`, `validation`) |

  The nightly run is the `daily` promotion itself: `release.yml` pushes `daily` with the Release-Gate App token, which triggers `pull-request.yml`. A night without new `develop` commits pushes nothing. `two-stage` and `single` topologies have no nightly run; `stable` runs the full suites when no evidence exists, and `single` relies on dispatch. On every `daily` push, a final `Daily CI triage alert` job (`scripts/github/daily_ci_alert.py`, `issues: write`, `--soft-fail` on transient API errors) opens or comments on a single deduplicated `<!-- daily-ci-failure -->` issue (`type/bug`, `area/ci`) when `Check & Test` or `Validation` fails, and comments and closes it automatically once `daily` passes cleanly.
- `Validation result` is a commit status (statuses API, `scripts/ci/validation_status.py`), not a check run, because GitHub counts a skipped required check run as passing: `pending` ("Add merge/auto to run Validation") on PR opened/synchronize/reopened that does not validate automatically (no `merge/auto`, and `SELF_MANAGED_MERGE` off or the PR a draft); `pending` ("Validation running") when a validating run starts; then `success` or `failure` from a final job that needs every validation job (path-skipped jobs count as success; a failed or skipped `gate` or `changes` job is a failure, including a failed preflight on a run that would have validated). Label events for other labels, edits, and cancelled runs post nothing, so a real result is never overwritten. Fork PRs cannot post (read-only token) and log a notice.
- Label and edit events run the same graph on the same head and wait for a running content run instead of cancelling it. Each suite then skips only when another run on this head already passed it (`scripts/ci/head_jobs.py`), so a newer skipped check run never hides an older failure of a required check. A `labeled` `merge/auto` event always starts Validation; any other label, edit or `ready_for_review` starts it only when the PR validates automatically and no validating run reported on the head.
- Duplicate-run avoidance (`scripts/ci/already_tested.sh`): because one workflow holds several suites, reuse is decided per suite, never by the run's conclusion. `--require-job` names the job that must have succeeded, `--substantive-job` the jobs that count as executed work, and `--pr-reuse-jobs` the jobs a previous head's run must have finished green or skipped. On a PR synchronize, `Check & Test` is reused when `Decide whether to run CI` and `Check & Test` succeeded or were skipped on the previous head and nothing in the `dart` scope changed; Validation evaluates `--target` scopes (`web`, `rules`) independently against a prior green `Validation status (result)`. On `merge-train/**` pushes, `Check & Test` is skipped when the exact SHA or the merged PR head's tree already has a successful `Check & Test`. On `weekly` and `stable` pushes only full evidence counts (`--push-only-reuse` on the same SHA, requiring `Full Dart suite` or `Web full E2E`), so a smoke or relational run never stands in for the nightly suites; `daily` never reuses them. Content runs cancel the previous run of the same PR; Dependabot runs are not cancelled by their own rebases. The merge gate evaluates only the latest executed run per check (by workflow and check name), ignoring superseded runs, newer skipped duplicates, and CANCELLED runs that a newer run of the same workflow on the head supersedes (`scripts/github/checks.py`; promotion applies the same evaluation).
- `merge-gate.yml` (`Merge gate`) — integrates PRs labeled `merge/auto` into `develop` one at a time (`merge/priority` ahead of normal `merge/auto`, oldest-first within each tier): waits for `Detect changed areas` and active adaptive reviews, requires a review attestation unless `SELF_MANAGED_MERGE=true`, supports `merge/freeze` / `MERGE_GATE_FREEZE` integration freezes without stripping `merge/auto`, and merges via `--rebase` when up to date with every head check green, otherwise rebases the oldest eligible `BEHIND` PR (`@dependabot rebase` for Dependabot). It listens to successful `pull_request` completions of `Pull Request` only (one wake-up per PR update instead of six), plus `pull_request_target` readiness and label events, `develop` pushes, a 30-minute schedule, and dispatch; the review dispatches it when an attestation for a `merge/auto` PR is posted. It validates the `RELEASE_GATE_APP_PRIVATE_KEY` PEM header before minting a token and runs as the Release-Gate App (or legacy `MERGE_GATE_TOKEN`) (ADR 0006, ADR 0007). It has no concurrency group: cancelled queued runs would mark `develop` red, so the script serializes instead.
- `release.yml` (`Release`) — promotion and delivery, with job dependencies instead of `workflow_run` chains:
  - `promote` (schedule or dispatch): fast-forward promotion along the linear release pipeline (`develop` -> `daily` at `0 4 * * *` UTC, `daily` -> `weekly` on Mondays at `0 5 * * 1` UTC, `weekly` -> `stable` on the 1st and 15th at `0 6 1,15 * *` UTC) via `scripts/github/promote_release.py` using the Release-Gate App (or legacy `MERGE_GATE_TOKEN`), validating the PEM header before minting, without creating merge commits (ADR 0007). The script fetches only the branches each step needs; a missing channel branch is never created (an owner action): scheduled runs report and skip missing branches, and manual runs fail. A target at or ahead of the source is a no-op. Divergent histories block the promotion. A missing gate token fails scheduled runs too when the topology is not `single` (no silent green); `make promote` is the manual bypass.
  - `build-web` on pushes to `daily`/`weekly`/`stable` that touch web paths, or dispatch; `build-android` on dispatch only (`make build-remote PLATFORM=android`). Both share `.github/actions/setup-flutter-app`.
  - `Evaluate release gate` (`scripts/release/release_gate.cjs`) runs on `daily`, `weekly`, and `stable` pushes (when Hosting is ready or, on `stable`, when `web_build` runs) and waits for the `Pull Request` push run of the same commit to succeed — its Check & Test and Validation jobs are the release prerequisites; agent validation is a develop-PR and weekly-schedule check and stays off stable pushes. It gates `hosting-deploy` on `daily`, `weekly`, and `stable` pushes (while `develop` pushes and manual dispatches skip the gate to stay fast), and on `stable` pushes `Release Web candidate` republishes this run's `web-build` artifact as `release-web-candidate` after both `build-web` and `release-gate` succeed (#145).
  - `hosting` (see [Firebase Hosting](#firebase-hosting)) with an environment-scoped post-deploy web probe (`.github/actions/web-probe`).
  - `docs-publish` on `stable` pushes that touch documentation paths, or dispatch: the strict MkDocs build and local navigation/asset validation, then GitHub Pages publishing of the vision, canonical spec, and project docs. This is the sole Pages deployment owner; documentation PRs and `daily`/`weekly` pushes run the same build in `pull-request.yml` without publishing.
  - Push path decisions come from `local_ci.py --release-filters`; the workflow's `on.push.paths` is their union, so pushes that touch none boot nothing. There is no workflow-level concurrency: each operation keeps its former group at job level, so a scheduled promotion and a channel push never cancel each other.
- `agent-ops.yml` (`Agent Ops`) — autonomous agent operations, one concurrency group per operation and item:
  - `implement` (issues labeled `triage/ready-for-agent`, or dispatch): runs the `implement-issue` agent workflow and opens a draft PR.
  - `review` (`pull_request_target` `opened`, `ready_for_review`, `synchronize`, `reopened`, trusted `@foodsavr-agent review` PR comments (OWNER/MEMBER/COLLABORATOR), or dispatch): automatic reviews are skipped while repository variable `SELF_MANAGED_MERGE` is `true`, or the legacy `AGENT_AUTO_REVIEW_ENABLED` is `false` (both unset means on; dispatch and trusted PR-comment requests still review). Only `SELF_MANAGED_MERGE=true` also lifts the merge gate's attestation requirement ([agent-system.md](agent-system.md#31-trusted-author-auto-merge--adaptive-review-policy)). It classifies non-draft, same-repository PRs via `scripts/github/pr_review.py`, computes a canonical `patch_id` (invariant across hunk line-offset shifts and file ordering, sensitive to binary hashes), carries over prior trusted approvals across patch-equivalent rebases (re-verified fail-closed in the privileged `Record review and attest` job without invoking any model), otherwise stages `.agents/state/pr-<N>.json` and `.md`, executes `integrate-pr.json` at the required adaptive review tier (`fast`, `balanced`, `deep`, or `human` advisory; `exempt` skips model invocation), records decisions on the `agent-review-history` branch, and posts a head-bound attestation comment (`<!-- agent-review: ... -->`). A separate `Wake the merge gate` job, the only one with `actions: write`, then dispatches the gate.
  - `audit`: the [nightly agent-system audit](agent-system.md#nightly-agent-system-audit) at midnight Europe/Oslo, or dispatch with `force`.
  - `incident` (owner-triggered dispatch): runs `pr_review.py bisect-learn` on the default branch and persists the escalating incident to the `agent-review-history` branch.
- `ops-maintenance.yml` (`Ops & Maintenance`) — `labels` syncs labels on issue/PR lifecycle changes (excluding `synchronize` and `closed`) with per-item concurrency; `fault-intake` (`repository_dispatch` `monitoring_fault`, every six hours, or dispatch) routes faults into deduplicated issues; `web-monitor` probes the live site every six hours or on dispatch; `deployment-poll` polls deployment levels daily (see [Deployment level](#deployment-level)).
- `manual-tools.yml` (`Manual Tools`) — dispatch-only developer utilities (`tool`): `android-drive-test` (see [Android test APK for manual testing](#android-test-apk-for-manual-testing)).
- Check rollups filter by workflow and job, never by workflow alone (`scripts/github/checks.py`): the merge gate, review, label sync, and promotion jobs are ignored, while failures of other jobs in the shared workflows (implementation, audit, monitoring, deploys) count. Names of the retired workflows stay matched for runs on older heads.
- `scripts/ci/local_ci.py` — local mirror of CI for changed areas (diffing against `origin/develop` by default; `make ci-local`); `pull-request.yml` runs its `agents`, `docs`, and `release` groups, `infra` covers `scripts/infra/test_*.py`, and its `dart` group is kept equal to `_reusable-dart-checks.yml`, which also pins the Flutter version. Group `paths` are the workflow scopes; `local_paths` only extend local coverage. The `agents` group discovers Python tests per directory (`unittest discover -p 'test_*.py'` over `scripts` and `scripts/agents`, `github`, `secrets`, `setup`, `monitoring`, `ci`, `web`, `human`), so new test files run without a list edit; any `scripts/ci/*.py`, `scripts/seed_global_catalog.py`, `scripts/test_*.py`, `lib/mock_data/global_products.dart`, or `lib/constants/product_categories.dart` change (as well as `daily` pushes and full dispatches) runs `Agent system validation`.
- The `.githooks/pre-push` hook (`make hooks`) runs `check_pr_base.py` and `local_ci.py --pre-push`, which only runs fast checks: a clean `git status`, `check_logs.py`, and for changed files `py_compile`, `actionlint` (workflows), `dart format` (Dart), `check_localizations.dart` (Dart or `assets/translations/`) and `check_shape_sync.dart` (models, schemas, registries, deleted Dart files). It runs `flutter pub get` only in a worktree without resolved packages, and skips a check whose tool is missing. build_runner, full analysis, the docs build and the test suites are left to PR CI.
- `scripts/ci/relevant_tests.py [paths…]` lists (`--print`, default) or runs (`--run`, without coverage) the tests affected by the diff against `origin/develop`: Dart tests by import closure and matching name, Python tests by name and referenced files, and Playwright specs by path heuristics. It is a convenience, not a gate.
- For matching pushes or non-fork `merge/auto` PRs, the `Firestore security rules` job runs the `firestore-rules/` Jest suite against the tracked `firestore.rules` in the Firestore emulator. Changes to `firestore.rules` or `firestore-rules/**` trigger it. Deploys are manual (`make infra-gcp-apply ENV=<environment>`, or the `make deploy-firestore-rules ENV=<environment>` bypass) until the release pipeline deploys rules ([ADR 0010](decisions/0010-track-firestore-rules-during-test-phase.md)).
- Default-branch (`develop`) ruleset requires PRs (rebase only), linear history, and up-to-date branches. The desired check set lives in `.agents/github/default-branch-ruleset.json`. Release branches (`daily`, `weekly`, `stable`) enforce linear history, no force pushes, no deletion, and fast-forward-only promotion.

Every automated step has a manual bypass that runs the same script locally with your own login, or dispatches the workflow: `make human LIST=1` lists them with what each needs from you (`scripts/human/menu.toml` is the single source; `scripts/human/test_humanctl.py` fails when an entry does not resolve). Examples: `make pr-merge` (merges on green required checks and `Validation result`, regardless of the adaptive review tier, bound to the verified head SHA), `make validate`, `make promote`, `make deploy-web`.

Workflow secrets fail gracefully. Missing `CODECOV_TOKEN` skips the optional coverage upload
with a warning. Release and Drive credentials remain explicit prerequisites;
their jobs stop with a named missing-secret error before attempting a publish.

## Firebase Hosting

The `hosting` operation of `release.yml` first resolves an environment and Hosting site from `deploy/instance.yaml`
(`levels env --channel`; see [deployment-levels.md](deployment-levels.md)): a push to a release
channel deploys live to the environment that declares it, `develop`, `daily` and `weekly` to their
own sites in the `test` project (GitHub Environment `test`) and `stable` to `production`.
`workflow_dispatch` (`operation: hosting`) takes inputs `environment` (default `auto`: the environment deploying the branch
for live, `staging`, else `test`, for previews) and `channel` (default: the branch). A live dispatch
whose channel the selected environment does not deploy fails with an error listing the valid
environment and channel pairs; `make deploy-web` refuses the same. It builds the web
app with the remote-backend app flavor (`--dart-define=FLAVOR=production`; web builds cannot pass
`--flavor`) and `--dart-define=DEPLOY_ENVIRONMENT=<environment>`, which selects that environment's
Firebase options, and deploys to its Firebase project, web app and site. All deployments are
skipped unless the owner explicitly sets repository variable
`FIREBASE_HOSTING_ENABLED=true`. Keep it unset while Hosting is disabled;
merging the workflow does not authorize enabling it.
Previews are manual only (`workflow_dispatch`, target `preview`: channel named after the branch,
expiring after input `expires` (default `4h`), linked on its PR; target `live` deploys live). It signs in
keylessly (Workload Identity Federation) and generates the selected environment's web-only
Firebase options from the Firebase API at build time
(`scripts/web/write_web_config.py`). A deploy is skipped, never failed, with a step summary naming
the bypass `make deploy-web ENV=<env> CHANNEL=<channel>` and the fix `make setup` when the environment
is not provisioned (`provisioned: false`), when `GCP_WORKLOAD_IDENTITY_PROVIDER` or
`GCP_DEPLOY_SERVICE_ACCOUNT` (suffixed per non-production environment, e.g. `_TEST`) is missing, or
when the service account belongs to another project than the environment's. Build and deploy logic
lives in `scripts/web/deploy_web.py`, shared by the workflow and `make deploy-web`. On `daily`, `weekly`, and `stable` pushes, `hosting-deploy` waits for `Evaluate release gate`; `develop` pushes and manual dispatches skip the gate. After every hosting run that does not fail (and was not blocked by `release-gate`), `Probe live web app` probes the site a live deploy replaced (`https://<site>.web.app`) with its resolved environment (`test` or `production`), else (preview or skipped deploy) `MONITOR_TARGET_URL` as `production`, using the default branch's monitor scripts. `fault_intake.py` tags healing issues with `<!-- healing-environment:<env> -->` and deduplicates per `(fingerprint, environment)`, and `verify_and_close.py` matches the probed environment so a clean `test` probe never closes an open `production` healing issue.
`ANDROID_APK_URL` (`/android` redirect) and the `WEB_ENV_B64` secret are optional.
`RECAPTCHA_ENTERPRISE_SITE_KEY` is optional only while App Check enforcement for
Firestore and Storage is `UNENFORCED`.
Before each deploy `scripts/web/hosting_storage_guard.py` flags builds over 5 GB and keeps Hosting storage
in budget: above 8 GB it deletes preview channels oldest-first and skips a
preview that would not fit; a live deploy may also delete live versions older
than the 3 latest to stay under 10 GB, and fails only if that is not enough.
Hosted web builds pass public client configuration from GitHub environment secret `WEB_ENV_B64` via `--dart-define=BUNDLED_ENV_B64=...` and keep the served `assets/.env` empty, while local `flutter run` still reads local `assets/.env`. An absent or empty web env is valid: the app starts with an empty environment (`lib/utils/env_loader.dart`) and integrations that need keys fail at use time.

## Cloud infrastructure

`infra/terraform` manages the GitHub deploy identity (one branch-and-environment
binding per release channel the environment deploys), the channels' extra Hosting
sites, web API key referrer restriction and App Check (reCAPTCHA Enterprise;
enforcement `UNENFORCED` until every client is registered) for one environment,
plus a monthly budget when the environment is on `firebase-blaze`. Apply with `ENV=<flavor> scripts/infra/apply.sh`
(owner gcloud login; values from `deploy/instance.yaml`). Existing GCS state
is retained; fresh Spark instances use private local state under
`.deployment-state/<project>/<flavor>`, which the owner must back up.
It also sets the Actions variables when `gh` is logged in.
Newcomers start with `scripts/infra/bootstrap.sh`
(prerequisites, human-only steps, then `apply.sh`).

## Deployment level

Deployment levels (ADR 0005) are checked in two places. On pull requests touching manifests,
deployment tooling, infrastructure, or the release and deployment workflows, `pull-request.yml` formats,
analyzes, and tests the package, validates manifests, and tests bootstrap
state selection and API-key discovery offline (`.github/actions/deploy-levels-check`). Daily (cron) and on
`workflow_dispatch`, the `deployment-poll` operation of `ops-maintenance.yml` runs the same check, then polls every cloud environment (matrix;
state per environment in `actions/cache`) and keeps one open issue labelled
`deployment-level` updated while any recommends `warn` or `promote`. Recommend-only:
there is no apply job; missing Workload Identity variables skip polling with a warning; `make deployment-poll ENV=<env>` polls with your own login.

## Versioning and release tags

The app version is the `version: MAJOR.MINOR.PATCH+BUILD` line of `pubspec.yaml` and follows [semantic versioning](https://semver.org). Flutter uses `MAJOR.MINOR.PATCH` as the Android `versionName` and iOS marketing version, and `BUILD` as the Android `versionCode` (`android/app/build.gradle.kts`) and iOS build number.

Choose the bump by the most significant change in the release:

- **MAJOR**: a breaking change for users, or a data or schema migration that is not backward compatible.
- **MINOR**: a new user-facing feature that is backward compatible.
- **PATCH**: fixes, copy, and styling.

A bump of any part resets the lower parts (major resets minor and patch; minor resets patch) and always increments `BUILD` by one, because store builds must increase monotonically.

Bump in the PR that ships the change, once, before it merges to `develop`; do not bump again for each promotion along `daily`, `weekly`, and `stable`, which only fast-forward the same commits. Run `make bump-version part=<major|minor|patch>` (default `patch`; add `DRY=--dry-run` to preview). It rewrites only the `version:` line (`scripts/version/bump_version.dart`) and prints the old and new values.

No workflow creates release tags today. When you tag a release by hand, tag the commit that carries the bump as `vMAJOR.MINOR.PATCH`, matching `pubspec.yaml` without the build number. The Android Play upload derives its version code from `ANDROID_VERSION_CODE_BASE` plus the Release run number (see [Android test APK for manual testing](#android-test-apk-for-manual-testing)), not from `BUILD`.

## Android test APK for manual testing

For a direct test install, dispatch the `android-drive-test` tool of
`manual-tools.yml` (`make android-apk`). It builds the production flavor against the existing
Firebase test project and uploads the APK directly to Drive. It does not upload
an Actions artifact, publish to Play, or write an APK into the repository. The
automatic Android delivery workflow and Play internal deployment have been
removed.
The workflow requires `GOOGLE_DRIVE_FOLDER_ID` and
`GOOGLE_DRIVE_OAUTH_JSON`. It reads the test project's Firebase defines from the
`FIREBASE_DEFINES_TEST` variable and derives the matching native Android
configuration from them (`scripts/ci/write_android_test_config.sh`).
`ANDROID_ENV_B64` may provide the bundled runtime configuration; when absent,
the workflow uses non-secret API endpoint defaults. It uses the debug signing
key intended for direct test installation.

For one-time interactive setup, run `bash scripts/release/setup_drive_deployment.sh`.
It lists the available Drive folders and lets you select one, authorizes the
active gcloud account with Drive access, validates the grant, and provisions `GOOGLE_DRIVE_ACCOUNT`,
`GOOGLE_DRIVE_FOLDER_ID`, and `GOOGLE_DRIVE_OAUTH_JSON` through `gh secret set`.
For noninteractive use, pass the folder ID as the first argument or set
`GOOGLE_DRIVE_FOLDER_ID`.
If gcloud requires a custom OAuth client, set `GOOGLE_OAUTH_CLIENT_ID_FILE`.
The helper never writes credentials to the repository or prints the account.

The existing remote Firebase project is the test environment; the production
project is declared in `deploy/instance.yaml` and created by `make setup`. Supply that existing project's files for
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

Normal CI builds compile `lib/firebase_options.dart` without defines (unconfigured; tests and emulators only).
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

The `Android smoke test` job of `pull-request.yml` (manual dispatch only) starts isolated Firebase emulators,
builds the development APK with `EMULATOR_HOST=10.0.2.2`, and records startup on
an Android virtual device. Its `android-visuals` artifact contains a screenshot,
startup video, and logs, retained for 14 days, including failure evidence when
available. These visuals show the development backend, not the remote test
project. Integration tests run in the same job after the smoke test.

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

## Integration Freeze, Priority Preemption, and Multiplexing Protocol

FoodSavr maintains a strictly linear, rebase-only `develop` history (`required_linear_history`, `allow_rebase_merge: true`, no merge or squash commits, zero admin bypass) feeding fast-forward release promotions (`develop` -> `daily` -> `weekly` -> `stable`). To coordinate urgent changes ahead of an active parallel batch — or recover cleanly when sibling agent threads are paused (for example on provider rate limits) — without overriding batch plans or stripping `merge/auto` labels, use the following protocol:

1. **Integration freeze (`merge/freeze` and `MERGE_GATE_FREEZE`)**:
   - Labeling an open coordinating issue (for example an urgent epic) with `merge/freeze` activates `batch` freeze in `scripts/github/merge_gate.py`.
   - Repository variable `MERGE_GATE_FREEZE` overrides the mode explicitly: `batch` freezes normal `merge/auto` PRs and pauses Dependabot auto opt-in while allowing `merge/priority` PRs through; `all` (or `true`) stops all PR merges, branch updates/rebases, and Dependabot auto opt-in (including priority PRs) while speculative train cleanup still deletes existing ephemeral `merge-train/pr-*` refs; unknown non-empty values or failed freeze-issue lookups fail closed to `all`.
   - Frozen PRs keep their `merge/auto` label intact and are reported as `frozen` in the gate summary so no batch state is lost.
   - If the freeze-aware gate is not yet deployed on `develop`, also disable `merge-gate.yml` (`gh workflow disable merge-gate.yml`), wait for any queued or in-progress `merge-gate.yml` runs to finish (or cancel them), confirm they have stopped, and recheck the queue before starting urgent work; re-enable `merge-gate.yml` once the update lands.
2. **Priority preemption (`merge/priority`)**:
   - Label urgent PRs with `merge/priority` (alongside `merge/auto` when gate-managed).
   - `merge_gate.py` orders `merge/priority` PRs ahead of normal `merge/auto` PRs (oldest-first within each tier) and holds in-scope ready PRs only behind higher-priority or older validating PRs, preventing priority inversions.
   - `risk/security` and one-way-door PRs still require human review and merge; `merge/priority` never bypasses approval boundaries or required checks.
3. **Batch and sibling-thread preservation**:
   - Before editing shared files, inspect every open PR's diff and hot-file hunk ranges so preempting PRs stay disjoint from active or quota-paused sibling PRs.
   - Record the freeze and preemption as a comment on the active `queue:batch` issue and in `.agents/events/` via `agentctl log`; never overwrite or delete the active batch's lanes or the planned next batch.
4. **Thaw**:
   - Once the preempting work lands on `develop` (and `merge-gate.yml` is re-enabled if disabled), remove `merge/freeze` from the coordinating issue and clear `MERGE_GATE_FREEZE` if set. Paused batch PRs automatically resume integration on the next gate reconciliation.
5. **Speculative rebase train (multiplexed validation)**:
   - After reconciling merges and updates, `scripts/github/merge_gate.py` builds ephemeral speculative branches `merge-train/pr-<N>` (configurable via repository variable `MERGE_TRAIN_DEPTH`, default `3`, capped at `5`, `0` disables) by linearly replaying eligible queued PRs (`develop -> P1' -> P2' -> ... -> Pk'`).
   - Slot 0 (`P1`) validates directly on its own PR branch; slots `1..depth` (`P2..Pk`) are pushed only when their combined `HEAD^{tree}` changes, avoiding duplicate CI runs. Any PR that conflicts on the speculative tip, contains merge commits, or has a failing check rollup on its current speculative tree is ejected from the speculative tip so downstream slots continue validating on the remaining prefix.
   - `pull-request.yml` runs `Check & Test` and Validation on `push` to `merge-train/**` (diffed against `develop`, never triggering deploy/release workflows). When `P1` lands and `P2` rebases onto `develop`, `scripts/ci/already_tested.sh` matches `P2`'s `HEAD^{tree}` byte-for-byte against its green non-skipped `merge-train/pr-<N>` push run (requiring a substantive non-control job and failing closed on fork PRs, tree mismatch, or skipped-only runs) and reuses the result.
   - Speculative refs respect `merge/freeze` and `merge/priority` (`batch` freeze speculates only on priority PRs; `all` freeze or `MERGE_TRAIN_DEPTH=0` cleans up all `merge-train/pr-*` refs). Slot 0 keeps its existing train ref alive until the PR leaves the queue, after which stale refs are deleted automatically.

