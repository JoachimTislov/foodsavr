# CI & Workflows

Absorbed from `.github/workflows/` @ 103a70f:

- `ci-checks.yml` — analyze, localization check, unit tests, coverage (runs on PRs to `develop` and pushes to `develop`/`main`).
- `build-web.yml` / `build-android.yml` — platform builds; Android emulator jobs pinned to `ubuntu-24.04` ahead of the Ubuntu 26 migration (#200/#189). Run on PRs to `develop` only when labeled `merge/auto`, and on pushes to `develop`/`main`.
- `docs-pages.yml` — strict MkDocs build and local navigation/asset validation on documentation PRs to `develop` and pushes to `develop`/`main`; `main` promotions publish the vision, canonical spec, and project docs to GitHub Pages. This is the sole Pages deployment owner; `build-web.yml` retains Flutter build artifacts without deploying them.
- `validation.yml` — expensive validation gates (smoke, E2E, Android integration, non-fork Firestore rules); gated on `merge/auto` for PRs to `develop` and also runs on pushes to `develop` (ADR 0007). `release-gated.yml` — release candidate workflow on `main` pushes (#145).
- For matching pushes or non-fork `merge/auto` PRs, Firestore rules are validated when the `FIRESTORE_RULES_B64` secret is configured; an unset secret emits a warning and skips validation. Rules themselves remain deliberately untracked (#165/#185).
- Duplicate-run avoidance: `scripts/ci/already_tested.sh` skips push runs of `ci-checks.yml` and `validation.yml` when the exact SHA already succeeded (e.g., fast-forward `develop` -> `main` promotion) or when the pushed commit tree equals a merged PR head tree with a green run of the same workflow; builds still run on push (release artifacts). Workflows use per-PR concurrency with cancel-in-progress; `ci-checks.yml` path-filters PRs inside its gate job so its checks always report.
- `merge-gate.yml` — integrates PRs labeled `merge/auto` into `develop` one at a time: waits for `Detect changed areas` (`Validation`) and merges via `--rebase` when up to date with every head check green, otherwise rebases the oldest `BEHIND` PR (`@dependabot rebase` for Dependabot); runs as `MERGE_GATE_TOKEN` (ADR 0006, ADR 0007).
- `promote.yml` — scheduled daily (`0 4 * * *` UTC) and manual (`workflow_dispatch`) fast-forward promotion of green `develop` -> `main` via `scripts/github/promote_main.py` using `MERGE_GATE_TOKEN`, triggering `main` deployment workflows without creating merge commits (ADR 0007).
- `scripts/ci/local_ci.py` — local mirror of CI for changed areas (diffing against `origin/develop` by default), run by the `.githooks/pre-push` hook (`make hooks`); `agent-system.yml` and `docs-pages.yml` run its `agents` and `docs` groups, and its `dart` group is kept equal to `ci-checks.yml` at CI's pinned Flutter version.
- Default-branch (`develop`) ruleset requires PRs (rebase only), linear history, up-to-date branches, and cheap checks `Decide whether to run CI` and `Check & Test`. `main` enforces linear history, no force pushes, no deletion, and fast-forward promotion from `develop`.

## Firebase Hosting

`firebase-hosting.yml` first resolves an environment (flavor) from `deploy/instance.yaml`
(`levels env`; see [deployment-levels.md](deployment-levels.md)): pushes to `main` use `production`;
`workflow_dispatch` input `environment` (default `auto`: `staging` for previews when the manifest
declares a cloud staging environment, else `production`). It builds the web app with
`--dart-define=FLAVOR=<environment>` (web builds cannot pass `--flavor`; `Config.environment`
falls back to `FLAVOR`) and deploys to that environment's Firebase project, web app and Hosting site
from the manifest (production: `my-foodsavr-store`). All deployments are
skipped unless the owner explicitly sets repository variable
`FIREBASE_HOSTING_ENABLED=true`. Keep it unset while Hosting is disabled;
merging the workflow does not authorize enabling it. Once enabled, pushes
to `main` deploy live;
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
