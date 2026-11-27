# ADR 0008: Reproducible, fork-safe setup, split IaC, and quota-aware direct harness routing

## Status

Accepted (explicit owner intent, November 22, 2026). Amends [ADR 0003](0003-autonomous-execution-boundary.md), [ADR 0005](0005-deployment-levels.md), [ADR 0006](0006-automated-integration-of-revertable-changes.md), and [ADR 0007](0007-develop-integration-branch-and-fast-forward-deploy.md).

The November 23, 2026 amendment to [ADR 0007](0007-develop-integration-branch-and-fast-forward-deploy.md#amendment--november-23-2026) defines the current branch names.

Workflow files named below were consolidated on November 27, 2026 (#496): `ci-checks.yml`, `validation.yml`, `agent-system.yml`, `traceability.yml`, the `docs-pages.yml` build and the `deployment-level.yml` PR check are jobs of `pull-request.yml`; `promote.yml`, `build-web.yml`, `build-android.yml`, `release-gated.yml`, `firebase-hosting.yml` and the Pages publish are operations of `release.yml`; `agent-implement.yml`, `agent-review.yml`, `agent-audit.yml` and `agent-incident.yml` are operations of `agent-ops.yml`; `fault-intake.yml`, `web-monitor.yml`, `github-labels.yml` and the `deployment-level.yml` poll are operations of `ops-maintenance.yml`; `android-drive-test.yml` is a tool of `manual-tools.yml`. See [ci-workflows.md](../ci-workflows.md).

## Context

FoodSavr's operational state (GitHub rulesets, Actions variables, channel branches, labels, WIF bindings, secrets, and CI harness auth) grew across imperative bash scripts, committed upstream defaults (`JoachimTislov/foodsavr`, `my-foodsavr-store`), and write-only secrets. That created three problems:

1. **Drift and silent failures**: existing upstream config drifted from repository expectations (missing `release` branch, ruleset drift, orphaned active workflows, `env.dart` not emitting `firebase_plan`).
2. **High contributor and fork friction**: non-owners cannot use upstream GitHub Secrets, bare `gh` commands target `upstream` after `gh repo fork`, enabling Actions triggers failing cron storms against upstream defaults, and fresh clones require manual scaffolding.
3. **Trust-boundary gaps**: broad WIF IAM conditions (`assertion.repository` only), `shell=True` secret sync, unblocked `risk/security` auto-merges, and static CI harness selection without quota awareness.

Our governing principle for repository operations is: **humans make decisions, agents make it possible**. Setup documentation and contracts must be agent-first (structured, deterministic) while remaining readable to humans, with zero custom free-text typing where auto-discovery works.

## Decision

### 1. Split Terraform into two independent roots

We manage declarative non-secret infrastructure in two separate Terraform roots with isolated state, providers, and permissions:

- **`infra/terraform/github/`** (repository-scoped, `integrations/github` only): manages split `github_repository_ruleset` resources, `github_repository_environment`, `github_actions_variable`, `github_actions_environment_variable`, singular `github_issue_label` resources (sourced from `.agents/github/labels.json`), and `github_branch_default`. Requires only `terraform` and `gh`.
- **`infra/terraform/gcp/`** (environment-scoped, `google-beta` only): manages GCP APIs, Firebase App Check, the Firestore `(default)` database (never destroyed), its rules release from `firestore.rules` and the indexes of `firestore.indexes.json`, the Google and Facebook sign-in providers, scoped Workload Identity Federation (WIF), billing budgets, and optional Blaze-only GCS buckets. Email/Password and Anonymous sign-in and the authorized domains of the Hosting sites are applied by `scripts/infra/firebase_config.py` from `apply.sh` (the Terraform resource needs billing to create and would replace domains added at runtime).

Local Terraform state (used on Firebase Spark and GitHub-only setups) must live outside git worktrees under `${XDG_STATE_HOME:-$HOME/.local/state}/foodsavr/terraform/<owner>/<repo>/<stack>/terraform.tfstate` so worktree deletion never destroys state. Terraform must never manage its own state bucket, destroy `github_repository`, manage moving channel branches with `prevent_destroy`, or overwrite live operational kill-switches (`FIREBASE_HOSTING_ENABLED`, `AUTO_HEAL_ENABLED`, `AUTO_HEAL_MERGE`, `AGENT_AUTO_REVIEW_ENABLED`, `SELF_MANAGED_MERGE`, `TELEMETRY_POLL_ENABLED`, `MONITOR_TARGET_URL`).

### 2. Separate untrusted author identity from trusted release-gate identity

We replace the manually rotated `MERGE_GATE_TOKEN` fine-grained PAT with a dedicated GitHub App while strictly separating author and integrator privileges:

- **`${OWNER}-${REPO}-agent`** (untrusted author, used by `agent-implement.yml`): holds `contents: write`, `pull_requests: write`, `issues: write`, and `metadata: read`. Must never hold `workflows: write`, `checks: write`, `actions: write`, or ruleset bypass.
- **`${OWNER}-${REPO}-release-gate`** (trusted integrator/promoter, used only by `merge-gate.yml` and `promote.yml` on trusted default-branch checkouts): holds `contents: write`, `pull_requests: write`, `issues: write`, `workflows: write`, and `metadata: read`.

Release-branch rulesets must be split into two rulesets per ADR 0007: one enforcing `deletion`, `non_fast_forward`, and `required_linear_history` with **zero** bypass actors, and a second enforcing `pull_request` where only `${OWNER}-${REPO}-release-gate` (and repository admins) may bypass. `scripts/github/checks.py` must verify `checkSuite.app.slug == "github-actions"`, and `scripts/github/merge_gate.py` must block `risk/security` PRs (including edits under `infra/terraform/`, `.github/workflows/`, and `.agents/policies/`).

### 3. Scope WIF by branch, environment, and role

We split GCP WIF impersonation into two least-privilege service accounts on the same Workload Identity Pool:

- **`github-deploy-live`**: deployment permissions only, bound to `assertion.repository`, the active release branch (`stable`, or `develop` in `single` topology), and `assertion.environment == 'production'`. Live WIF variables are stored on the `production` GitHub Environment.
- **`github-telemetry-ro`**: read-only monitoring/Firestore/Auth viewer permissions for `fault-intake.yml` and `deployment-level.yml`.

### 4. Configurable release topologies (`RELEASE_TOPOLOGY`)

Release topology is selected during setup and stored in a GitHub Actions variable (`RELEASE_TOPOLOGY`):

- **`single`** (default for forks and personal setups): `develop` only; `promote.yml` cleanly no-ops and deploy/build workflows trigger on `develop`.
- **`two-stage`**: `develop -> stable`; fast PR checks on `develop`, explicit or scheduled fast-forward promotion to `stable`.
- **`full-channels`** (upstream FoodSavr default): `develop -> daily -> weekly -> stable` per ADR 0007.

Missing channel branches are created idempotently via the GitHub Refs API during setup and never deleted automatically on topology downgrade. Private repositories on GitHub Free automatically disable ruleset provisioning (`enable_rulesets = false`) rather than failing `403`.

### 5. Secret boundaries and fork-safe configuration

- **Never put secret values in `terraform.tfstate` or LLM context** (one exception: the 2026-11-27 sign-in provider amendment below). Stateless `scripts/secrets/rotate.py` (using declarative `sync_file` + `encode` instead of `shell=True`, explicit `--repo`, and interactive TTY confirmation) pushes secret values directly to GitHub Secrets.
- **Keep `FIRESTORE_RULES_B64` and `FIREBASE_OPTIONS_B64` out of fork-exposed `vars.*`.** Only non-sensitive identifiers (`AGENT_APP_ID`, `RELEASE_GATE_APP_ID`, `FIREBASE_APP_ID_ANDROID`, `FACEBOOK_APP_ID`, `FACEBOOK_CLIENT_TOKEN`, `ROUTER_MODEL`) move to GitHub Actions Variables. `ROUTER_BASE_URL` must always pass policy `allow_hosts` validation.
- **CI vs. local config split**: local tools read gitignored `.agents/instance.local.json` (worktrees read the main checkout's file); CI workflows read GitHub Actions Variables (`vars.*`) and never fall back to upstream defaults (amended November 26, 2026). Scheduled workflows skip cleanly (`exit 0`) when unconfigured so enabling Actions on a fork never triggers failure storms or probes upstream URLs.

### 6. Agent-prepares / human-executes setup (`setupctl.py`, `setup-system`, `make setup`)

A single idempotent engine (`scripts/setup/setupctl.py` with `probe`, `plan`, `apply`, and `verify`) powers both the agent skill (`.agents/skills/setup-system/SKILL.md`) and the human terminal CLI (`make setup`) across three profiles: `local-dev`, `fork-agents`, and `full-cloud`.

- If a non-owner selects a profile requiring GitHub/CI control, setup forks safely (`gh repo fork --clone=false --remote=true --default-branch-only=false` + `gh repo set-default <owner>/<repo>`), passes `--repo` explicitly everywhere, and enables Actions only after vars and secrets are ready.
- Agents execute read-only probes, collect multiple-choice human decisions, and prepare non-secret files (`local-dev` stubs, `tfvars`, `import` blocks). Humans execute irreversible cloud/secret writes in their own terminal (`make infra-apply` with a saved `-out=tfplan`, and `make secrets-sync`), preserving ADR 0003.

### 7. Direct multi-harness quota-aware selection (ported from T3 Code)

CI and local automated workflows invoke vendor harnesses directly (`claude`, `codex`, `agy`) without a third-party gateway proxy. Harness selection ports the MIT-licensed subscription usage-limit probing and exhaustion logic from `pingdotgg/t3code` into `scripts/agents/harness_usage.py`:

- **Claude (`claude`)**: queries `get_usage` via stream-json control protocol for `five_hour` (session) and `seven_day` (weekly) utilization and reset timestamps.
- **Codex (`codex`)**: queries `codex app-server` JSON-RPC `account/rateLimits/read` for `primary` and `secondary` windows.
- **Antigravity (`agy`)**: queries `v1internal:retrieveUserQuotaSummary` (fallback `fetchAvailableModels`) using `~/.gemini/antigravity-cli/antigravity-oauth-token` (or uses API-key mode with `GEMINI_API_KEY`). If Google rejects the saved login, `agy models` refreshes it through the native CLI. A login that still fails needs owner sign-in.
- **Routing rule**: skip any harness with an exhausted active window (`used_percent >= threshold` and `resets_at > now`), then select the policy-safe installed harness with the highest remaining headroom (`min(100 - used_percent)` across blocking windows), then rank API-key and unknown-quota harnesses in that order. Cache normalized probe results for one minute. Use task routing to choose the model for the selected harness.

## Considered options

- **Single Terraform root with `enable_github` / `enable_gcp` toggles**: rejected because GitHub state is repo-scoped while GCP state is environment-scoped; combining them risks destroying production GCP resources during staging applies and breaks unconditional `import {}` blocks.
- **Unified single GitHub App for authoring, merge gate, and promotion**: rejected because `merge-gate.yml` and `promote.yml` require `workflows: write` and ruleset bypass, which would let a prompt-injected issue modify CI workflows on an in-repo branch and steal secrets/WIF tokens.
- **Terraform `github_branch` with `prevent_destroy = true`**: rejected because downgrading `RELEASE_TOPOLOGY` permanently deadlocks `terraform plan`, and brand-new empty repositories fail with HTTP 409.
- **Third-party model proxy (`yetone/magpie`) in CI**: rejected for now because it adds a third-party proxy in the secret/prompt path, does not remove underlying CLIs for Claude/Antigravity subscriptions, and breaks zero-infra fork reproducibility if self-hosted.

## Consequences

- Any developer can contribute via `local-dev` with zero cloud accounts or secrets, or run an autonomous personal fork/new repo with minimal secrets and zero dirty git diffs.
- `scripts/setup/monitoring.sh` and `scripts/setup/agent_router.sh` will be retired once `setupctl.py` and Terraform cover their responsibilities.
- `agent-implement.yml` automatically steers around exhausted subscriptions when multiple harness credentials are configured, without introducing external proxy infrastructure.

## Amendment — November 26, 2026: stateless repository

Owner directive: tracked files hold no instance state. Project ids, Hosting sites, web app ids, buckets, billing accounts and client options live only in GitHub Actions variables and secrets (CI), environment variables, and gitignored local state (`.agents/instance.local.json`, `.agents/state/`, `${XDG_STATE_HOME}`). Tooling resolves them from there, and a fork works after `make setup` without code changes.

- `deploy/instance.yaml` keeps the shared ladder and environment shapes; every cloud environment is `provisioned: false` there. The levels CLI deep-merges the instance overlay over it: `DEPLOY_INSTANCE` (CI, from the Actions variable) or `deployInstance` in `.agents/instance.local.json`. `make setup` records identities in the overlay and the GitHub Terraform root publishes it (`instance_variables`).
- `lib/firebase_options.dart` reads compile-time defines; setup writes them to `.agents/state/firebase.defines.json` (CI: `FIREBASE_DEFINES_<ENV>`). The production apply gate requires the production identity in the published `DEPLOY_INSTANCE`, replacing the merged-manifest check.
- The session archive reads its project, bucket and billing account from `AGENT_SESSION_*` or `sessionArchive` in the local state.
- Workflows drop `github.repository == '<upstream>'` fallbacks; unset variables skip cleanly.

## Amendment — November 27, 2026: declared health, no manual checks

Owner directive: operators and agents work on deterministic abstractions, not on agents connecting loose pieces. A check done by hand once becomes automation, so it never has to be done by hand again.

- **One declaration.** [`scripts/setup/health.toml`](../../../scripts/setup/health.toml) lists every condition of a ready instance per profile: local files, GitHub apps and policy, published environments, per-environment WIF, live Hosting sites, a CD run that actually deployed (a green run that skipped counts as failed), web monitoring, social sign-in and the session archive. Each check names the one command that fixes it.
- **One interpreter.** [`scripts/setup/health.py`](../../../scripts/setup/health.py) evaluates the declaration, with one evaluator per `kind`. `make setup-verify` (`setupctl verify`) and the final `make setup` step (Platform health) print the same report. Offline, the live checks report "not probed" and never count as healthy.
- **Extend, don't scatter.** A new manual check is a new `[[check]]` entry. A new `kind` is added only when no existing kind fits. Health logic lives nowhere else.
- **Keep the CLIs.** Domain CLIs stay usable on their own (`social_auth.sh`, `monitoring.sh`, `agentctl`, `rotate.py`, `make deploy-web`). Health calls their `--check` modes and names them as the fix, and `make setup` runs them in sequence. It does not replace them.

## Amendment — November 27, 2026: sign-in provider secrets in gcp state

Owner directive: Terraform configures the Google and Facebook sign-in providers. `google_identity_platform_default_supported_idp_config` requires `client_secret` and does not mark it sensitive, so the gcp state holds both client secrets. This is the only exception to the no-secrets-in-state rule.

- The secrets reach Terraform only as `TF_VAR_identity_provider_secrets` (a `sensitive` variable, redacted in plans) from `.env` (`GOOGLE_WEB_CLIENT_SECRET`, `FACEBOOK_APP_SECRET`); never on the command line, in tfvars or in logs.
- The gcp state, its backups and saved plans stay `0600`, outside git; GCS state stays in the private project bucket. A leak of any of them rotates the `gcp-terraform-state` group (`scripts/secrets/registry.toml`).
- A provider without credentials is not managed. Once managed, `apply.sh` refuses to plan without its credentials, so a missing `.env` value never removes sign-in; the providers use `deletion_policy = "ABANDON"`.
- Creating the Google OAuth web client and the Meta app has no API and stays in `scripts/human/google` and `scripts/human/meta`; `scripts/setup/social_auth.sh` only checks the providers.

## Amendment — November 28, 2026: self-managed merge and CI tiers

Owner directive (#532). Amends [ADR 0006](0006-automated-integration-of-revertable-changes.md) and [ADR 0007](0007-develop-integration-branch-and-fast-forward-deploy.md).

- **`SELF_MANAGED_MERGE`** replaces `AGENT_AUTO_REVIEW_ENABLED` as the live operational switch. `true` stops automatic reviews and lifts the merge gate's review attestation requirement; agents and humans manage reviews and GitHub native auto-merge. Structural blockers and explicit human holds stay ([agent-system.md](../agent-system.md#31-trusted-author-auto-merge--adaptive-review-policy)). For the transition, `AGENT_AUTO_REVIEW_ENABLED=false` still stops automatic reviews, but never relaxes the gate.
- **No validation hold when self-managed**: every non-draft `develop` PR runs smoke Validation without waiting for `merge/auto`, so GitHub native auto-merge can complete on required checks alone.
- **CI tiers**: `develop` PRs run relational Dart tests and Playwright smoke. The `daily` push runs the full Dart suite with coverage and desktop and mobile Playwright; `weekly` and `stable` reuse that evidence for the same SHA. A regression that only the full suites catch can therefore reach `develop` and is found on the nightly run, before it can reach `weekly`.
- **Pre-push** runs only fast, change-scoped static checks; PR CI is the verification ([ci-workflows.md](../ci-workflows.md)).
