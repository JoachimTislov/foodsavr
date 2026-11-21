# CI & Workflows

Absorbed from `.github/workflows/` @ 103a70f:

- `ci-checks.yml` — analyze, localization check, unit tests, coverage.
- `build-web.yml` / `build-android.yml` — platform builds; Android emulator jobs pinned to `ubuntu-24.04` ahead of the Ubuntu 26 migration (#200/#189). Web builds produce an Actions artifact; GitHub Pages deployment is removed.
- `validation.yml` — validation gates; `release-gated.yml` — release candidate workflow (#145).
- For matching non-pull-request changes, Firestore rules are validated when the `FIRESTORE_RULES_B64` secret is configured; an unset secret emits a warning and skips validation. Rules themselves remain deliberately untracked (#165/#185).
- Duplicate-run avoidance: `scripts/ci/already_tested.sh` skips push-to-`main` runs of `ci-checks.yml` and `validation.yml` only when the pushed commit tree equals a merged PR head tree with a green run of the same workflow; builds still run on push (release artifacts). Workflows use per-PR concurrency with cancel-in-progress; `ci-checks.yml` path-filters PRs inside its gate job so its checks always report.
- Default-branch ruleset requires PRs (rebase only), linear history, up-to-date branches and checks `Decide whether to run CI`, `Check & Test`, `Detect changed areas`, `Web smoke test`, `Android smoke test`.

Workflow secrets fail gracefully. Missing `FIREBASE_OPTIONS_B64` creates a
compile-only placeholder and records a warning instead of producing an opaque
base64 or file error. Missing `CODECOV_TOKEN` skips the optional coverage upload
with a warning. Missing Firestore rules already skips that optional validation
with a warning. Release and Drive credentials remain explicit prerequisites;
their jobs stop with a named missing-secret error before attempting a publish.

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

For one-time setup, run `bash scripts/release/setup_drive_deployment.sh
<drive-folder-id>`. It authorizes the active gcloud account with Drive access,
validates the grant, and provisions `GOOGLE_DRIVE_ACCOUNT`,
`GOOGLE_DRIVE_FOLDER_ID`, and `GOOGLE_DRIVE_OAUTH_JSON` through `gh secret set`.
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
