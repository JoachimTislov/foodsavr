# ADR 0005: Declarative deployment levels and environments

## Status

Accepted (explicit owner intent, given 2026-11-21 in the session that produced this ADR; satisfies ADR 0002 for the concepts below)

## Context

Owner intent, verbatim: "We need support different levels of deployment in various locations, first one is firebase, free level, next is its subscription. I would like to scale in relation to user count, like KEDA in kubernetes but for providers such as firebase, supabase and more. If someone wants to run the app on web free level this is now supported. Philosophy is to make it really easy for anyone to bootstrap their instance of the app, can be done in separate PR since it's wide. When any third party provider becomes too expensive we need to allow for level with both hybrid and fully standalone cloud deployment. ... declared and comprehensive system to support multiple types of deployments."

Follow-up intent, same session: every level must support the environments `development`, `test`, `staging`, `production`, following the app's flavor convention (`Config.environment`: `appFlavor`, else `--dart-define=FLAVOR`).

Today the instance runs on Firebase Spark (billing disabled): Auth, Firestore, App Check, Hosting. Project ids were hard-coded in scripts, Terraform and workflows. Web builds over 5 GB are already flagged by `scripts/web/hosting_storage_guard.py` (#239).

## Decision

1. **Manifest.** An instance is declared in `deploy/instance.yaml`, shaped by `schemas/deployment-instance.schema.json` (anchor: `packages/foodsavr_deploy/lib/src/model/deployment_instance.dart`). This extends ADR 0004's approved shape set. Tooling reads identity from it instead of hard-coding it.
2. **Levels ladder.** Levels are an ordered, shared ladder. Each level names provider, plan, status (`built` | `spec-ahead`), limits (unit and period in the key), capability **bindings** and a migration from the previous level. Bindings (`auth`, `documents`, `hosting`, `appCheck`, … → `provider/service`) make hybrid and standalone levels expressible (cf. Score/Crossplane: abstract capability, provider chosen per level).
3. **Environments.** Environment = flavor × level. Names are fixed to the four flavors; `production` is required. Each environment has its own `currentLevel`, cloud identity and optional trigger/behavior overrides. `development`/`test` may run on emulators (no identity, not polled). Two environments may share a cloud project only via `sharedWith`; the shared-with environment owns the infrastructure.
4. **Triggers (KEDA-inspired).** Pluggable scalers read a metric; thresholds are ratios of usage to the **current level's** limit with `warn`/`promote`/`demote` bands (hysteresis). A band must hold for `stabilizationPolls` consecutive polls; demotion also waits `minDwell` (cooldown). On metric failure the poller **holds** and alerts after `fallback.alertAfterFailures`; it never promotes on missing data.
5. **Migration classes.** `inPlace` < `redeploy` < `dataMove` < `authMove`, derived from the binding diff; a declared class may not understate it. Only `inPlace` may run without a per-transition approval, and only in mode `auto`; the default mode is `recommend`. `dataMove`/`authMove` always need owner approval (future: a GitHub Environment with required reviewers).
6. **Paid levels declare a budget.** Provider budgets alert but never cap (Blaze); a paid level must declare `budget` (optional kill switch). Billing changes remain owner-approved per ADR 0003; setting `mode: auto` with a budget in a reviewed manifest is that pre-approval for `inPlace` transitions only.
7. **Recommend-only in phase 1.** `levels poll` and the deployment-poll operation of `.github/workflows/ops-maintenance.yml` recommend (`hold`/`warn`/`promote`/`demote`) and keep one issue updated; nothing mutates infrastructure.

## Phases

1. Firebase Spark/Blaze: manifest, schema, `foodsavr_deploy` CLI, Firebase scalers, Terraform `level` + budget, bootstrap script, workflows (this ADR).
2. App backend port (`Config.backend`, `IBackendBootstrap`, `@Environment(<provider>)`, domain `AppUser`), `test`/`staging` app flavors, Supabase levels.
3. Hybrid levels (e.g. Firebase Auth + Supabase data).
4. Standalone self-host (Supabase docker or PocketBase).

## Consequences

- Forks bootstrap by editing one manifest (`scripts/infra/bootstrap.sh`).
- Limits live in the manifest only; prose cites keys, not numbers.
- Spec-ahead levels are contracts, not drift; their limits are research, not measurements.
- Live polling needs `roles/monitoring.viewer` and `roles/firebaseauth.viewer` on the deploy service account.
