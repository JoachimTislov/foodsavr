# CI & Workflows

Absorbed from `.github/workflows/` @ 103a70f:

- `ci-checks.yml` — analyze, localization check, unit tests (app tests with `flutter test`, selected `packages/foodsavr_core` tests with `dart test` in the package, both through `scripts/ci/run_tests.dart`; a broken package test fails `Check & Test`), coverage (scoped to Dart/Flutter/package paths and `scripts/ci/*.dart`; runs strictly on PRs to `develop` and pushes to release branches `daily`/`weekly`/`stable`, not on `develop` pushes). Release-script checks (`scripts/release/**`) run in a separate lightweight `Check release scripts` job (`local_ci.py --group release`) without installing Flutter.
- `build-web.yml` / `build-android.yml` — platform release-artifact builds on `push` to release branches `daily`/`weekly`/`stable` (and `workflow_dispatch`), sharing `.github/actions/setup-flutter-app`; Android emulator jobs pinned to `ubuntu-24.04` ahead of the Ubuntu 26 migration (#200/#189).
- `docs-pages.yml` — strict MkDocs build and local navigation/asset validation on documentation PRs to `develop` and pushes to `daily`/`weekly`/`stable`; `stable` promotions publish the vision, canonical spec, and project docs to GitHub Pages. This is the sole Pages deployment owner; `build-web.yml` retains Flutter build artifacts without deploying them.
- `validation.yml` — expensive change-gated validation using `scripts/ci/dep_impact.py` for Dependabot bumps and grouping Web smoke + Playwright E2E (`Web smoke test`) and Android smoke + integration tests (`Android smoke test`) into single setup/emulator runs, plus non-fork Firestore rules; gated on `merge/auto` for PRs to `develop` and runs on pushes to release branches `daily`/`weekly`/`stable` (not on `develop` pushes; ADR 0007). `develop` PRs get the same path-gated Web smoke + E2E and Android smoke + integration coverage as release-channel pushes (narrowed only by `dep_impact.py`), because `develop` pushes do not re-validate. Because GitHub counts a skipped required check run as passing, the workflow also posts a `Validation result` commit status (statuses API, `scripts/ci/validation_status.py`) on the PR head or pushed SHA: `pending` ("Add merge/auto to run Validation") on PR opened/synchronize/reopened without `merge/auto`; `pending` ("Validation running") when a validating run starts; then `success` or `failure` from a final job that needs all validation jobs (jobs skipped by the path decision count as success, a failed or skipped `changes` gate as failure). A `labeled` event for any other label and a cancelled run post nothing, so a real result is never overwritten. Fork PRs cannot post (read-only token) and log a notice; Dependabot `pull_request` runs get a read-only token by default, which the job-level `permissions: statuses: write` raises. `release-gated.yml` — release candidate workflow on `stable` pushes (#145). `dependency-review.yml` runs on dependency manifest/lockfile PRs only.
- For matching pushes or non-fork `merge/auto` PRs, the `Firestore security rules` job runs the `firestore-rules/` Jest suite against the tracked `firestore.rules` in the Firestore emulator. Changes to `firestore.rules` or `firestore-rules/**` trigger it. Deploys are manual (`make deploy-firestore-rules ENV=<environment>`) until the release pipeline deploys rules ([ADR 0010](decisions/0010-track-firestore-rules-during-test-phase.md)).
- Duplicate-run avoidance: `scripts/ci/already_tested.sh` skips push runs of `ci-checks.yml` when the exact SHA already succeeded (e.g., fast-forward promotion between release branches) or when the pushed commit tree equals a merged PR head tree with a green run of the same workflow; `validation.yml` uses `--push-only-reuse` so `develop -> daily` always runs the full release-branch validation suite while `daily -> weekly -> stable` reuses the green `daily` push run; builds still run on release-branch pushes (release artifacts). Workflows use per-PR concurrency with cancel-in-progress; `ci-checks.yml` path-filters PRs inside its gate job so its checks always report. On a PR synchronize (for example a rebase), the same script skips whole workflows when nothing in scope changed since a qualifying green run on the previous head, and in `validation.yml` also evaluates `--target` scopes (`web`, `android`, `integration`, `rules`) independently (requiring a prior green `Validation status (result)` job) so unrelated base changes reuse untouched targets; Dependabot PR runs are not cancelled by their own rebases so the previous run finishes first. The merge gate holds only in-scope merges behind higher-priority or older validating PRs. Label events for labels other than `merge/auto` run in their own concurrency group, so they never cancel a running `validation.yml`; the merge gate evaluates only the latest executed run per check (by workflow and check name), ignoring superseded runs and newer skipped duplicates; a CANCELLED run is also ignored when a newer run of the same workflow (higher workflow-run id) exists on the same head, since concurrency cancellation supersedes it even if the newer run skipped that job (`scripts/github/checks.py`; promotion applies the same evaluation).
- `merge-gate.yml` — integrates PRs labeled `merge/auto` into `develop` one at a time (`merge/priority` ahead of normal `merge/auto`, oldest-first within each tier): waits for `Detect changed areas` (`Validation`) and active `Agent review` runs, supports `merge/freeze` / `MERGE_GATE_FREEZE` integration freezes without stripping `merge/auto`, and merges via `--rebase` when up to date with every head check green, otherwise rebases the oldest eligible `BEHIND` PR (`@dependabot rebase` for Dependabot); listens only to successful `pull_request` completions of PR-gating workflows, validates the `RELEASE_GATE_APP_PRIVATE_KEY` PEM header before minting a token, and runs as the Release-Gate App (or legacy `MERGE_GATE_TOKEN`) (ADR 0006, ADR 0007).
- `promote.yml` — periodic and manual (`workflow_dispatch`) fast-forward promotion along the linear release pipeline (`develop` -> `daily` at `0 4 * * *` UTC, `daily` -> `weekly` on Mondays at `0 5 * * 1` UTC, `weekly` -> `stable` on the 1st and 15th at `0 6 1,15 * *` UTC) via `scripts/github/promote_release.py` using the Release-Gate App (or legacy `MERGE_GATE_TOKEN`), validating the PEM header before minting and triggering release-branch checks and `stable` deployment workflows without creating merge commits (ADR 0007). The script fetches only the branches each step needs; a missing channel branch is never created (an owner action): scheduled runs report and skip missing branches, and manual runs fail. A target at or ahead of the source is a no-op. Divergent histories block the promotion. A missing gate token fails scheduled runs too when the topology is not `single` (no silent green); `make promote` is the manual bypass.
- `agent-review.yml` — classifies non-draft, same-repository PRs (`opened`, `ready_for_review`, `synchronize`, `reopened`, and `workflow_dispatch`) via `scripts/github/pr_review.py`, computes a canonical `patch_id` (invariant across hunk line-offset shifts and file ordering, sensitive to binary hashes), carries over prior trusted approvals across patch-equivalent rebases (re-verified fail-closed in the privileged `publish` job without invoking any model), otherwise stages `.agents/state/pr-<N>.json` and `.md`, executes `integrate-pr.json` at the required adaptive review tier (`fast`, `balanced`, `deep`, or `human` advisory; `exempt` skips model invocation), records decisions on the `agent-review-history` branch, and posts a head-bound attestation comment (`<!-- agent-review: ... -->`).
- `agent-incident.yml` — owner-triggered (`workflow_dispatch`): runs `pr_review.py bisect-learn` on the default branch and persists the escalating incident to the `agent-review-history` branch.
- `traceability.yml` / `agent-system.yml` / `github-labels.yml` — `traceability.yml` runs `agentctl check-pr` and `scripts/agents/check_logs.py` on every PR so append-only `.agents/events/**` logs are validated quickly without triggering the full `agent-system.yml` suite (`!.agents/events/**`). `github-labels.yml` syncs labels on issue/PR lifecycle changes (excluding `synchronize` and `closed`) with per-item concurrency.
- `scripts/ci/local_ci.py` — local mirror of CI for changed areas (diffing against `origin/develop` by default), run by the `.githooks/pre-push` hook (`make hooks`); `agent-system.yml`, `docs-pages.yml`, and `ci-checks.yml` (`release-scripts`) run its `agents`, `docs`, and `release` groups, `infra` covers `scripts/infra/test_*.py`, and its `dart` group is kept equal to `ci-checks.yml` at CI's pinned Flutter version. The `agents` group discovers Python tests per directory (`unittest discover -p 'test_*.py'` over `scripts/agents`, `github`, `secrets`, `setup`, `monitoring`, `ci`, `web`, `human`), so new test files run without a list edit, and any `scripts/ci/*.py` change triggers `agent-system.yml`.
- Default-branch (`develop`) ruleset requires PRs (rebase only), linear history, up-to-date branches, and checks `Decide whether to run CI`, `Check & Test`, and `Validation result`. Release branches (`daily`, `weekly`, `stable`) enforce linear history, no force pushes, no deletion, and fast-forward-only promotion.

Every automated step has a manual bypass that runs the same script locally with your own login, or dispatches the workflow: `make human LIST=1` lists them with what each needs from you (`scripts/human/menu.toml` is the single source; `scripts/human/test_humanctl.py` fails when an entry does not resolve). Examples: `make pr-merge` (merges on green required checks and `Validation result`, regardless of the adaptive review tier, bound to the verified head SHA), `make validate`, `make promote`, `make deploy-web`.

Workflow secrets fail gracefully. Missing `CODECOV_TOKEN` skips the optional coverage upload
with a warning. Release and Drive credentials remain explicit prerequisites;
their jobs stop with a named missing-secret error before attempting a publish.

## Firebase Hosting

`firebase-hosting.yml` first resolves an environment (flavor) from `deploy/instance.yaml`
(`levels env`; see [deployment-levels.md](deployment-levels.md)): pushes to `stable` use `production`;
`workflow_dispatch` input `environment` (default `auto`: `staging` for previews when the manifest
declares a cloud staging environment, else `production`). It builds the web app with
`--dart-define=FLAVOR=<environment>` (web builds cannot pass `--flavor`; `Config.environment`
falls back to `FLAVOR`) and deploys to that environment's Firebase project, web app and Hosting site
from the manifest (production: `my-foodsavr-store`). All deployments are
skipped unless the owner explicitly sets repository variable
`FIREBASE_HOSTING_ENABLED=true`. Keep it unset while Hosting is disabled;
merging the workflow does not authorize enabling it. Once enabled, pushes
to `stable` deploy live;
previews are manual only (`workflow_dispatch`, target `preview`: channel named after the branch,
expiring after input `expires` (default `4h`), linked on its PR; target `live` deploys live). It signs in
keylessly (Workload Identity Federation) and generates the web-only
`firebase_options.dart` from the Firebase API at build time
(`scripts/web/write_web_config.py`). Missing `GCP_WORKLOAD_IDENTITY_PROVIDER` or
`GCP_DEPLOY_SERVICE_ACCOUNT` Actions variables (suffixed per non-production environment, e.g.
`_STAGING`) fail the job while hosting is enabled, naming the bypass `make deploy-web ENV=<env>` and the fix
`make infra-gcp-apply ENV=<env>`; there is no silent skip. Build and deploy logic lives in
`scripts/web/deploy_web.py`, shared by the workflow and `make deploy-web`.
`RECAPTCHA_ENTERPRISE_SITE_KEY`, `ANDROID_APK_URL` (`/android` redirect) and the
`WEB_ENV_B64` secret are optional.
Before each deploy `scripts/web/hosting_storage_guard.py` flags builds over 5 GB and keeps Hosting storage
in budget: above 8 GB it deletes preview channels oldest-first and skips a
preview that would not fit; a live deploy may also delete live versions older
than the 3 latest to stay under 10 GB, and fails only if that is not enough.
`WEB_ENV_B64` becomes `assets/.env`, which Hosting serves publicly. An empty or missing `assets/.env` is valid: the app starts with an empty environment (`lib/utils/env_loader.dart`) and integrations that need keys fail at use time.

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
there is no apply job; missing Workload Identity variables skip polling with a warning; `make deployment-poll ENV=<env>` polls with your own login.

## Android test APK for manual testing

For a direct test install, use the manually dispatched `Android test APK to
Google Drive` workflow. It builds the production flavor against the existing
Firebase test project and uploads the APK directly to Drive. It does not upload
an Actions artifact, publish to Play, or write an APK into the repository. The
automatic Android delivery workflow and Play internal deployment have been
removed.
The workflow requires `GOOGLE_DRIVE_FOLDER_ID` and
`GOOGLE_DRIVE_OAUTH_JSON`. It reads the tracked `lib/firebase_options.dart`
for the Firebase test project and derives the matching native Android
configuration from it (`scripts/ci/write_android_test_config.sh`).
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

Normal CI builds use the tracked `lib/firebase_options.dart`.
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
   - `ci-checks.yml` and `validation.yml` run on `push` to `merge-train/**` (diffed against `develop`, never triggering deploy/release workflows). When `P1` lands and `P2` rebases onto `develop`, `scripts/ci/already_tested.sh` matches `P2`'s `HEAD^{tree}` byte-for-byte against its green non-skipped `merge-train/pr-<N>` push run (requiring a substantive non-control job and failing closed on fork PRs, tree mismatch, or skipped-only runs) and reuses the result.
   - Speculative refs respect `merge/freeze` and `merge/priority` (`batch` freeze speculates only on priority PRs; `all` freeze or `MERGE_TRAIN_DEPTH=0` cleans up all `merge-train/pr-*` refs). Slot 0 keeps its existing train ref alive until the PR leaves the queue, after which stale refs are deleted automatically.

