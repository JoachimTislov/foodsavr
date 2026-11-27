# ADR 0007: `develop` integration branch and fast-forward release channel promotions

## Status

Accepted (explicit owner intent, 2026-11-22: #292 — introduce `develop` as the integration branch, keep expensive feedback loops in the merge queue, rename `main` to `release` as the deployment branch, forbid merge commits everywhere, and promote green commits via periodic fast-forward channels `nightly`, `beta`, `stable`, and `release`). Amends [ADR 0003](0003-autonomous-execution-boundary.md) and [ADR 0006](0006-automated-integration-of-revertable-changes.md).

The November 23, 2026 amendment below supersedes the original channel names, schedules, and deployment branch.

Workflow files named below were consolidated on November 27, 2026 (#496): `ci-checks.yml`, `validation.yml`, `agent-system.yml`, `traceability.yml`, the `docs-pages.yml` build and the `deployment-level.yml` PR check are jobs of `pull-request.yml`; `promote.yml`, `build-web.yml`, `build-android.yml`, `release-gated.yml`, `firebase-hosting.yml` and the Pages publish are operations of `release.yml`; `agent-implement.yml`, `agent-review.yml`, `agent-audit.yml` and `agent-incident.yml` are operations of `agent-ops.yml`; `fault-intake.yml`, `web-monitor.yml`, `github-labels.yml` and the `deployment-level.yml` poll are operations of `ops-maintenance.yml`; `android-drive-test.yml` is a tool of `manual-tools.yml`. See [ci-workflows.md](../ci-workflows.md).

## Context

Under ADR 0006, every PR targeted `main`, every PR push ran expensive emulator/Playwright/build workflows, and every merged PR immediately triggered deployment pipelines (`firebase-hosting.yml`, `release-gated.yml`, `docs-pages.yml`). Separating integration from release channels lets contributors iterate against fast checks on `develop`, gates expensive checks in the merge queue, eliminates stale-`main` divergence noise, and provides periodic release cadences (`nightly`, `beta`, `stable`, `release`).

Two GitHub constraints shape the design:

1. **No native merge queue on user-owned repositories**: `merge_group` requires an organization-owned repository. The existing custom merge gate (`merge-gate.yml` + `scripts/github/merge_gate.py`) already serializes one PR at a time and merges only when the exact tested head passes every check; moving expensive workflows behind the `merge/auto` label emulates a `merge_group` queue without losing any guarantee.
2. **No merge commits and no SHA drift**: The repository disallows merge commits and squash merges (`allow_merge_commit: false`, `allow_squash_merge: false`, `allow_rebase_merge: true`). GitHub's "Rebase and merge" button rewrites commit SHAs (setting GitHub as committer), which would cause release branches and `develop` to diverge after the first promotion. Advancing release branches by **fast-forward** (`git push ... <source_sha>:refs/heads/<channel>`) preserves linear history, creates zero merge commits, and deploys the exact commit SHA validated on `develop`.

## Decision

### Branch roles

- **`develop`** (default branch): Integration branch. All feature, fix, and Dependabot PRs target `develop`.
- **`nightly`**: Daily periodic release channel (`0 4 * * *` UTC), fast-forwarded from green `develop`.
- **`beta`**: Weekly periodic release channel (`0 5 * * 1` UTC, Mondays), fast-forwarded from green `nightly`.
- **`stable`**: Biweekly periodic release channel (`0 6 1,15 * *` UTC, 1st & 15th), fast-forwarded from green `beta`.
- **`release`** (renamed from `main`): Exclusively the production deployment branch. Fast-forwarded from `stable` on the biweekly schedule or manually via `workflow_dispatch` (from `stable`, `beta`, `nightly`, or `develop`).

### Cheap PR checks vs. merge-queue & release-branch checks

- **PR-time (cheap)**: `ci-checks.yml` (matching `scripts/ci/local_ci.py`), `agent-system.yml`, `docs-pages.yml` (`build`), `traceability.yml`, and `dependency-review.yml` run on every PR targeting `develop`.
- **No duplicate `develop` push runs**: Merging a PR into `develop` does not re-run CI check workflows on `develop`; only `merge-gate.yml` reconciles the next queued PR.
- **Queue-time & release-branch (expensive)**: `validation.yml` (web/Android smoke, Playwright E2E, Android integration, non-fork Firestore rules) runs on `pull_request` when the PR carries `merge/auto` and on `push` to release branches (`nightly`, `beta`, `stable`, `release`). `build-android.yml` and `build-web.yml` produce release artifacts on `push` to `nightly`, `beta`, `stable`, and `release`. Amendment (owner request, 2026-11-27): Android smoke, Android integration and `build-android.yml` run only on manual dispatch.
- **`merge_gate.py`** targets `develop`, waits for `"Detect changed areas"` (`Validation` entrypoint) to complete with `SUCCESS` on the PR head (in addition to `rollup == "SUCCESS"`), and integrates one PR at a time via `--rebase`.

### Periodic and manual fast-forward promotions (`develop -> nightly -> beta -> stable -> release`)

- `.github/workflows/promote.yml` runs `scripts/github/promote_release.py` on three cron schedules (`0 4 * * *` daily `develop -> nightly`, `0 5 * * 1` weekly `nightly -> beta`, `0 6 1,15 * *` biweekly `beta -> stable -> release`) and via `workflow_dispatch` (selecting target `channel`, optional `source`, and `dry_run`).
- Each promotion step verifies the target branch is an ancestor of the source branch (never force-pushes) and blocks on any failed or pending checks. Promoting from `develop` (`develop -> <release branch>`) advances into the release pipeline and triggers release-branch checks; promoting between release branches (`nightly -> beta -> stable -> release`) strictly requires a green check rollup and completed `"Detect changed areas"` (`SUCCESS`) on that exact commit SHA before fast-forwarding `refs/heads/<target>` using `MERGE_GATE_TOKEN`. Advancing `release` triggers deployment workflows (`firebase-hosting.yml`, `build-android.yml` + `build-web.yml` -> `release-gated.yml`, `docs-pages.yml` Pages deploy).

### Rulesets & rollback

- `develop` (`~DEFAULT_BRANCH`) requires PRs (rebase-only), linear history, no force-pushes, and green cheap checks (`Decide whether to run CI`, `Check & Test`).
- Release branches (`refs/heads/release`, `refs/heads/nightly`, `refs/heads/beta`, `refs/heads/stable`) enforce `deletion`, `non_fast_forward`, and `required_linear_history` with no bypass, plus a `pull_request` rule with admin bypass so the owner's `MERGE_GATE_TOKEN` promotion workflow can fast-forward them while blocking direct pushes by other actors.
- **Rollback**: Revert the offending commit via a PR to `develop`, then promote forward through the affected channels (fast-forward).

## Consequences

- Feature PRs get fast CI feedback without running 30–60 minute emulator/build jobs on intermediate pushes.
- No merge commits are ever created on `develop` or any release branch, and every channel points to an exact commit tested on `develop`.
- `promote.yml` halts visibly if `MERGE_GATE_TOKEN` is missing/expired or if a channel ever diverges from its upstream.
- `already_tested.sh` recognizes exact-SHA successes so fast-forwarded `release` pushes skip redundant `ci-checks.yml` and `validation.yml` work while keeping `release-gated.yml` satisfied.


## Amendment — November 23, 2026

The owner approved `develop → daily → weekly → stable`. Each cut advances one channel by fast-forward:

- `daily` advances from `develop` at 04:00 UTC every day.
- `weekly` advances from `daily` at 05:00 UTC every Monday.
- `stable` advances from `weekly` at 06:00 UTC on the 1st and 15th of each month. It is the final channel and the production deployment branch.

`RELEASE_TOPOLOGY=full-channels` uses all three cuts. The `two-stage` topology cuts directly from `develop` to `stable` on the stable schedule. The `single` topology uses `develop` only. A first cut can start release-branch CI on a SHA whose PR passed integration and has no failing or pending checks. Later cuts require green Validation on the source SHA.

Channel setup can seed missing `daily` and `weekly` refs from `nightly` and `beta` when those commits are in `develop` and at or ahead of any existing `stable` ref. Setup uses `develop` when a legacy seed cannot meet those conditions. It preserves and reports existing legacy branches. The channel rulesets, production environment policy, and live WIF branch binding follow the active topology.
