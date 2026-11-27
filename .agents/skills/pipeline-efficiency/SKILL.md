---
name: pipeline-efficiency
description: Keep CI green and fast across local verification, develop integration, and release promotion. Use before pushing or opening a PR, when auditing CI failures or runner waste, when designing or trimming GitHub Actions workflows, or when sequencing rebases in a linear-history queue.
metadata:
  audience: agent
---

# Pipeline efficiency

Shift failures left to local commands, path-gate every check so a PR runs only what its change can break, keep release builds and publishes on promotion, and isolate repo-wide CI outages before amplifying them across a queue. `develop` pushes do not re-run Validation (ADR 0007), so the `develop` PR run is the last smoke/E2E check before promotion and is never thinned below the paths a change touches.

## 1. Local-first preflight

Run the cheapest exact mirror of CI before every push. Install `.githooks/` once per clone with `make hooks`.

1. Verify the branch is current on `origin/develop`:
   ```sh
   python3 scripts/ci/check_pr_base.py
   ```
2. Run the changed-area CI mirror:
   ```sh
   python3 scripts/ci/local_ci.py
   ```
3. `local_ci.py` already runs the `agents`, `docs`, `dart`, `release`, `infra` (includes `packages/foodsavr_deploy/**` and `deploy/**`) and `workflows` (`actionlint`) groups for changed paths; there is no separate deploy-manifest group. Run separately only what it cannot:
   - **`firestore.rules` or `firestore-rules/**`**: start the Firestore emulator and run `npm --prefix firestore-rules test`.
   - **Traceability**: confirm every commit carries an `Agent-Session:` trailer (`scripts/agents/agentctl check-pr --base origin/develop --head HEAD`).
   - **Runner environment**: CI sets `GITHUB_REPOSITORY`; when a suite reads it, run it once with `GITHUB_REPOSITORY=example/test-repo` so local settings do not mask a failure.
4. Before setting a secret from a local file via `scripts/secrets/rotate.py`, validate the source locally (for example, a valid PEM header and structure for GitHub App private keys). `lib/firebase_options.dart` is tracked in git, not synced to a secret.

Done when every check matching the branch's changed paths exits 0 on a clean tree.

## 2. Circuit-break repo-wide outages

Before pushing a batch, adding `merge/auto` across open PRs, or triggering bulk reruns, inspect recent workflow health:

```sh
gh run list --limit 10 --json name,conclusion,event,createdAt,headBranch
```

When two or more unrelated PRs fail on the same infrastructure step (for example `Invalid keyData` minting an App token, corrupt Firebase client options, or an upstream CLI installer flag change):

1. Hold bulk reruns and leave queued PRs untouched.
2. Fix or escalate the single root cause.
3. Re-run **one canary PR** and verify the failing step turns green before waking the rest of the queue.

Done when shared CI prerequisites are verified green on one canary PR before queueing other PRs.

## 3. Tier checks by branch boundary

Place each check in the earliest, cheapest tier that still enforces its safety property:

| Tier | Target | What belongs here | Keep out of this tier |
|---|---|---|---|
| **Local pre-push** | Developer / agent worktree | `check_pr_base.py`, `local_ci.py`, `scripts/infra`, `scripts/release`, `foodsavr_deploy`, `actionlint`, secret format validation | Multi-minute emulator boots |
| **`develop` PR** | Integration gate | `pull-request.yml`: preflight in `Decide whether to run CI` (PR base, traceability, dependency review), path-filtered `Check & Test` (Dart/Flutter code only), `Validate manifests and test levels CLI` (deploy/infra paths only), `Firestore security rules` (rules paths only), `Agent system validation` (agent/script paths excluding `.agents/events/**`); `Validation` (Web smoke + E2E; Android smoke + integration only on manual dispatch) for app paths, which starts when `merge/auto` is added (before that the `Validation result` status stays pending) | Release APK/Web artifact builds, full site publishes, emulator runs for non-app edits, `synchronize` label churn |
| **Release channels (`daily`, `weekly`, `stable`)** | Promotion | `develop -> daily` runs the full release `Validation`; `daily -> weekly -> stable` reuse the green `daily` run for the same SHA (`already_tested.sh --push-only-reuse`); `release.yml` builds Web on release pushes that touch its app/build paths (path-filtered) and Android only on manual dispatch; only `stable` publishes GitHub Pages and deploys production | Unverified manual skips |

When authoring or tightening `.github/workflows/*.yml`:

- **Align path filters across all three layers**: `scripts/ci/local_ci.py` `GROUPS`/`CI_FILTERS`/`RELEASE_FILTERS` (the workflows decide through `--ci-filters`/`--release-filters`), `release.yml` `on.push.paths`, and `scripts/ci/already_tested.sh` pathspecs; `test_local_ci.py` checks them.
- **Keep non-app edits out of Flutter/Android jobs**: Python-only `scripts/ci/*.py` and `scripts/release/**` changes belong in Python/Node unit checks, not `flutter build apk` or KVM Android Emulator runs.
- **Keep append-only event logs out of heavy suites**: `.agents/events/**` records are checked by `check_logs.py` in the `Decide whether to run CI` preflight, not the full 300+ test `Agent system validation` suite on unrelated UI/docs PRs.
- **Trim workflow fan-out**: add a PR check as a job of `pull-request.yml`, never as a new `pull_request` workflow, so one run carries every PR check and `merge-gate.yml` keeps a single `workflow_run` subscription (`Pull Request`); trigger the `labels` job of `ops-maintenance.yml` on `[opened, edited, ready_for_review, converted_to_draft]` rather than every `synchronize`.
- **Reuse per suite, not per run**: `pull-request.yml` holds several suites, so `already_tested.sh` calls name the suite's jobs (`--require-job`, `--substantive-job`, `--pr-reuse-jobs`); a run's overall conclusion never proves a suite passed.
- **Fail loudly on misconfiguration, degrade cleanly on optional providers**: enabled deploys with missing config fail instead of skipping green; optional review tiers with no available provider cap or skip instead of posting `blocked`.

Done when every workflow trigger and path filter matches its tier and mirrors `local_ci.py` and `already_tested.sh`.

## 4. Low-churn queue and rebase discipline

Under `develop`'s linear-history and strict up-to-date ruleset, eager rebases multiply CI load quadratically (`O(N^2)`). Coordinate with the `pr-merge` skill and `queue-planner` skill:

1. **Batch locally**: group fixes and formatting into one clean push instead of dribbling fixups that cancel in-flight runs.
2. **Let the gate rebase opted-in PRs**: the merge gate updates the oldest `BEHIND` PR that carries `merge/auto` once no opted-in PR is running checks (ADR 0006). Rebase manually only branches without `merge/auto` and security-path PRs that need a human merge, and then only the next one in the queue.
   Before rebasing or pushing a branch that carries `merge/auto`, remove the label and fetch: the gate may already have rebased it. Re-add the label only when the branch is finalized again.
3. **Protect in-flight Validation**: avoid rebasing or pushing a PR while its Validation run is in progress (unless fixing a known failure); cancelling mid-run wastes runner minutes and prevents `already_tested.sh` from reusing a green previous head.
4. **Order low-blast-radius PRs first**: among independent ready PRs, land docs/agent/script PRs before app PRs so `already_tested.sh` skips re-running Dart and Validation on subsequent app PRs when nothing in their scope changed.
5. **Opt in once, when finalized**: the author adds `merge/auto` to a two-way-door PR once its acceptance is met and review feedback is addressed (ADR 0006), and the gate handles ordering; adding it at creation or mid-review causes open-then-label cancellation races.
6. **Stack only on true diff dependencies**: cap stack depth at 1; independent work targets `develop`.

Done when each PR runs at most one CI pass per real code change and one rebase at merge time.

## 5. Audit recent integrations

When asked to diagnose red CI runs, runner-minute burn, cancellation waste, or integration throughput, read [CI pipeline audit](references/ci-audit.md) and run its measurement loop.
