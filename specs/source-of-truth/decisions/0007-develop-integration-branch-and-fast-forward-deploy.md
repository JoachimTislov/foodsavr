# ADR 0007: `develop` integration branch and fast-forward deployment promotion to `main`

## Status

Accepted (explicit owner intent, 2026-11-22: #292 — introduce `develop` as the integration branch, keep expensive feedback loops in the merge queue, make `main` deployment-only, forbid merge commits everywhere, and promote green `develop` to `main` on a schedule via fast-forward). Amends [ADR 0003](0003-autonomous-execution-boundary.md) and [ADR 0006](0006-automated-integration-of-revertable-changes.md).

## Context

Under ADR 0006, every PR targeted `main`, every PR push ran expensive emulator/Playwright/build workflows, and every merged PR immediately triggered deployment pipelines (`firebase-hosting.yml`, `release-gated.yml`, `docs-pages.yml`). Separating integration from deployment lets contributors iterate against fast checks on `develop`, gates expensive checks in the merge queue, and isolates `main` as a clean release branch.

Two GitHub constraints shape the design:

1. **No native merge queue on user-owned repositories**: `merge_group` requires an organization-owned repository. The existing custom merge gate (`merge-gate.yml` + `scripts/github/merge_gate.py`) already serializes one PR at a time and merges only when the exact tested head passes every check; moving expensive workflows behind the `merge/auto` label emulates a `merge_group` queue without losing any guarantee.
2. **No merge commits and no SHA drift**: The repository disallows merge commits and squash merges (`allow_merge_commit: false`, `allow_squash_merge: false`, `allow_rebase_merge: true`). GitHub's "Rebase and merge" button rewrites commit SHAs (setting GitHub as committer), which would cause `main` and `develop` to diverge after the first promotion. Advancing `main` by **fast-forward** (`git push ... <develop_sha>:refs/heads/main`) preserves linear history, creates zero merge commits, and deploys the exact commit SHA validated on `develop`.

## Decision

### Branch roles

- **`develop`** (default branch): Integration branch. All feature, fix, and Dependabot PRs target `develop`.
- **`main`**: Exclusively the deployment branch. Only fast-forward promotions from green `develop` write to `main`.

### Cheap PR checks vs. merge-queue expensive checks

- **PR-time (cheap)**: `ci-checks.yml` (matching `scripts/ci/local_ci.py`), `agent-system.yml`, `docs-pages.yml` (`build`), and `dependency-review.yml` run on every PR targeting `develop`.
- **Queue-time (expensive)**: `validation.yml` (web/Android smoke, Playwright E2E, Android integration, non-fork Firestore rules) and `build-android.yml` / `build-web.yml` run on `pull_request` only when the PR carries `merge/auto` (and on `push` to `develop` / `main` as needed).
- **`merge_gate.py`** targets `develop`, waits for `"Detect changed areas"` (`Validation` entrypoint) to complete with `SUCCESS` on the PR head (in addition to `rollup == "SUCCESS"`), and integrates one PR at a time via `--rebase`.

### Scheduled and manual fast-forward promotion (`develop` -> `main`)

- `.github/workflows/promote.yml` runs `scripts/github/promote_main.py` on a daily schedule (`0 4 * * *` UTC) and via `workflow_dispatch`.
- Promotion verifies `main` is an ancestor of `develop` (never force-pushes), checks that no checks on `develop` HEAD are pending or failed and that `"Detect changed areas"` completed with `SUCCESS`, and fast-forwards `refs/heads/main` to `develop` HEAD using `MERGE_GATE_TOKEN` so GitHub Actions triggers deployment workflows (`firebase-hosting.yml`, `build-android.yml` + `build-web.yml` -> `release-gated.yml`, `docs-pages.yml` Pages deploy).

### Rulesets & rollback

- `develop` (`~DEFAULT_BRANCH`) requires PRs (rebase-only), linear history, no force-pushes, and green cheap checks (`Decide whether to run CI`, `Check & Test`).
- `main` enforces `deletion`, `non_fast_forward`, and `required_linear_history` with no bypass, plus a `pull_request` rule with admin bypass so the owner's `MERGE_GATE_TOKEN` promotion workflow can fast-forward `main` while blocking direct pushes by other actors.
- **Rollback**: Revert the offending commit via a PR to `develop`, then promote `develop` -> `main` (fast-forward).

## Consequences

- Feature PRs get fast CI feedback without running 30–60 minute emulator/build jobs on intermediate pushes.
- No merge commits are ever created on `develop` or `main`, and `main` always points to an exact commit tested on `develop`.
- `promote.yml` halts visibly if `MERGE_GATE_TOKEN` is missing/expired or if `main` and `develop` ever diverge.
- `already_tested.sh` recognizes exact-SHA successes so fast-forwarded `main` pushes skip redundant `ci-checks.yml` work while keeping `release-gated.yml` satisfied.
