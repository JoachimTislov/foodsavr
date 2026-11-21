# CI & Workflows

Absorbed from `.github/workflows/` @ 103a70f:

- `ci-checks.yml` — analyze, localization check, unit tests, coverage.
- `build-web.yml` / `build-android.yml` — platform builds; Android emulator jobs pinned to `ubuntu-24.04` ahead of the Ubuntu 26 migration (#200/#189).
- `validation.yml` — validation gates; `release-gated.yml` — release workflow (#145).
- For matching non-pull-request changes, Firestore rules are validated when the `FIRESTORE_RULES_B64` secret is configured; an unset secret emits a warning and skips validation. Rules themselves remain deliberately untracked (#165/#185).
- Duplicate-run avoidance: `scripts/ci/already_tested.sh` skips push-to-`main` runs of `ci-checks.yml` and `validation.yml` only when the pushed commit tree equals a merged PR head tree with a green run of the same workflow; builds still run on push (release artifacts). Workflows use per-PR concurrency with cancel-in-progress; `ci-checks.yml` path-filters PRs inside its gate job so its checks always report.
- Default-branch ruleset requires PRs (rebase only), linear history, up-to-date branches and checks `Decide whether to run CI`, `Check & Test`, `Detect changed areas`, `Web smoke test`, `Android smoke test`.

## Firebase Hosting

`firebase-hosting.yml` first resolves an environment (flavor) from `deploy/instance.yaml`
(`levels env`; see [deployment-levels.md](deployment-levels.md)): pushes to `main` use `production`;
`workflow_dispatch` input `environment` (default `auto`: `staging` for previews when the manifest
declares a cloud staging environment, else `production`). It builds the web app with
`--dart-define=FLAVOR=<environment>` (web builds cannot pass `--flavor`; `Config.environment`
falls back to `FLAVOR`) and deploys to that environment's Firebase project, web app and Hosting site
from the manifest (production: `my-foodsavr-store`). Pushes to `main` deploy live;
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
