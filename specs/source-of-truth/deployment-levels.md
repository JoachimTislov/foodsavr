# Deployment Levels

Why and how a FoodSavr instance moves between hosting levels, per environment. Decision: [ADR 0005](decisions/0005-deployment-levels.md). Truth lives in shapes; this page explains them and cites keys, never numbers.

| What | Where (authoritative) |
|---|---|
| Manifest shape | [schemas/deployment-instance.schema.json](schemas/deployment-instance.schema.json) |
| Owner's instance (levels, limits, triggers, environments) | [`deploy/instance.yaml`](../../deploy/instance.yaml) |
| Bring-your-own-Firebase template | [`deploy/examples/firebase-free-web.yaml`](../../deploy/examples/firebase-free-web.yaml) |
| Semantics (validation, bands, plan, poll, env) | `packages/foodsavr_deploy` (`bin/levels.dart`) and its tests |
| Deploy-time Hosting guard (5 GB build flag, storage budget) | `scripts/web/hosting_storage_guard.py` |

## Model

- **Instance** = identity (name, GitHub repo, region) + capabilities the app needs + a shared **ladder** of levels + **triggers** + **behavior** + **environments**.
- **Level** = provider + plan + limits + capability **bindings** (`capability → provider/service`). Changing bindings is how a level becomes hybrid (Firebase Auth + Supabase data) or standalone (self-hosted). `status: spec-ahead` levels are contracts the repository cannot run yet.
- **Environment** = one app flavor (`development`, `test`, `staging`, `production`) at one level, with its own identity. Production may sit on Blaze while development stays on Spark. `emulator: true` environments need no cloud identity and are not polled. Shared projects need `sharedWith`.
- **Trigger** = scaler (metric source) + the current level's limit key + `warn`/`promote`/`demote` ratio bands. Scalers: `firebaseAuthUsers` (total users, a conservative proxy for active users), `firestoreDailyOps` (highest daily count over 7 days), `hostingStorage` (FINALIZED version bytes, as the guard measures), `deployGuard` (evaluated by the guard at deploy time, not polled), `file` (dry runs).

## Behavior

`levels poll` evaluates the active triggers of one environment: band from ratio, then
**promote** when any trigger stays in its promote band for `stabilizationPolls` polls;
**warn** when any is in warn/promote but not yet stable, or a metric has failed `fallback.alertAfterFailures` times;
**demote** when every trigger with a demote band has held it for `stabilizationPolls` polls and the environment has been on its level for `minDwell`;
otherwise **hold**. A failed read keeps the previous band but resets its streak
(never promotes on missing data). On paid levels limits are the free allowance;
a ratio above 1 means paying. Budgets alert; they do not cap spend.

`levels plan` describes current → target: migration class (derived from the binding diff), reversibility, approval, billing, declared or derived steps. Approval is required unless the class is `inPlace` and the mode is `auto`.

## Bootstrap seam

`levels env --env <flavor> --format dotenv|github|tfvars` emits `FLAVOR`, project/web app/site ids, region, state bucket/prefix, Actions-variable suffix and Terraform variables. Consumers:

- `scripts/infra/bootstrap.sh` — newcomer entry point: prerequisites, human-only steps, then `apply.sh`.
- `scripts/infra/apply.sh` — Terraform per environment (`ENV=<flavor>`).
  Existing remote state stays in `gs://<project>-tfstate`, prefix `firebase`
  (production) or `firebase-<flavor>`. Fresh Spark instances use private local
  state under `.deployment-state/<project>/<flavor>`; keep a private backup.
  `TF_STATE_BACKEND=auto|local|gcs` selects storage without automatic migration.
  Missing web API-key IDs are discovered from Firebase; Actions variables
  are suffixed per environment.
- `.github/workflows/firebase-hosting.yml` — builds with the environment's
  `FLAVOR` and honors its configured GitHub Environment approval gates.
- `.github/workflows/deployment-level.yml` — polls each cloud environment.

## Legal documents per environment (spec-ahead)

Each environment ships its own legal document set, decided in [ADR 0009](decisions/0009-legal-documents-per-environment.md); the manifest shape is [contracts/legal-documents.schema.json](contracts/legal-documents.schema.json).

- `development`, `test` and `staging` get tester terms. These environments may hold real data with no persistence guarantee, so privacy obligations still apply.
- `production` gets the full privacy policy, terms of service and subscription terms, in `nb` and `en`.
- The environment's Firebase Hosting landing page serves the same version the app bundles (#371).
- Production goes live with paid plans only after the pre-paid-launch legal review; paid-plan prototyping stays in `test` until then.

Today the app bundles one English document pair for every environment (`assets/legal/`, `lib/constants/legal_docs.dart`), and only `development` and `production` flavors exist.

## Provider research (2026-11)

Recorded as manifest limits/notes. Known conflicts, kept conservative: Identity Platform active-user caps (Spark DAU vs Blaze MAU); Hosting transfer (per-day on the pricing page vs per-month on the quotas page). Cloud Storage is unavailable on Spark since 2026-02-03; Spark has no Functions or Firestore export/PITR/TTL. Supabase Free pauses after a week of inactivity, has no static hosting (pair with Firebase Hosting or Cloudflare Pages) and no App Check equivalent. Usage APIs: Identity Toolkit `accounts:batchGet` (paginated count), Cloud Monitoring `timeSeries.list` (`firestore.googleapis.com/document/*_ops_count`), Hosting `sites/{site}/versions`, Supabase Management API `analytics/endpoints/usage.api-counts` (phase 2). Migration gotchas: Firebase scrypt hashes import into GoTrue; 28-char Firebase UIDs need a UUID mapping; Firestore export needs Blaze; App Check is lost off Firebase.

## Phase 2 seam (spec-ahead)

- **Backend port**: `Config.backend` dart-define; `IBackendBootstrap` replaces the Firebase-specific startup in `lib/main.dart` and `lib/service_locator.dart`; provider implementations registered with injectable `@Environment(<provider>)`; `IAuthService` returns a domain `AppUser` instead of Firebase types. Products/collections already sit behind `IProductRepository`/`ICollectionRepository`.
- **Flavors**: `lib/main.dart` `supportedFlavors` and Android `productFlavors` (`android/app/build.gradle.kts`) only know `development`/`production`; `Config` has `isDevelopment`/`isProduction` only. Adding `test`/`staging` means: extend `supportedFlavors`, add `Config.isTest`/`isStaging` (emulators for `test`), add Android flavors with app-id suffixes, and per-flavor Firebase options. Until then a non-production cloud environment builds web only.
- **Executor**: a gated `promote` job (GitHub Environment with reviewers) that runs `levels plan` and `apply.sh`.
