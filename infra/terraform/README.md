# FoodSavr Terraform Roots (ADR 0008)

Infrastructure is split into two independent Terraform roots with isolated state, providers, and credentials:

| Root | Scope | Provider | Entry point | State location |
| --- | --- | --- | --- | --- |
| `infra/terraform/github/` | Per repository | `integrations/github` (`~> 6.0`) | `scripts/infra/apply-github.sh` | `${XDG_STATE_HOME:-$HOME/.local/state}/foodsavr/terraform/<owner>/<repo>/github/terraform.tfstate` |
| `infra/terraform/gcp/` | Per Firebase/GCP environment (APIs, Hosting sites, web API key, App Check, Firestore database, rules and indexes, Google/Facebook sign-in, WIF) | `hashicorp/google-beta` (`~> 7.0`) | `scripts/infra/apply.sh` | GCS bucket on Blaze; `${XDG_STATE_HOME:-$HOME/.local/state}/foodsavr/terraform/<owner>/<repo>/gcp-<project>-<env>/terraform.tfstate` on Spark |

## Security invariants

1. **No secret values in state, with one exception**: Terraform manages non-secret identifiers and IAM bindings; secrets are synced statelessly via `scripts/secrets/rotate.py`. The exception is the Google and Facebook sign-in client secrets in the gcp root (`auth.tf`, ADR 0008 amendment of 2026-11-27): `scripts/infra/apply.sh` passes them from `.env` as `TF_VAR_identity_provider_secrets` (sensitive, redacted in plans), and the gcp state, its backups and saved plans then hold them. Those files stay `0600` and outside git (`PLAN_OUT` inside the repository is refused); a leaked state rotates the `gcp-terraform-state` group.
2. **No live kill-switch overrides**: Operational toggles (`FIREBASE_HOSTING_ENABLED`, `AUTO_HEAL_ENABLED`, `AUTO_HEAL_MERGE`, `AGENT_AUTO_REVIEW_ENABLED`, `TELEMETRY_POLL_ENABLED`, `MONITOR_TARGET_URL`) are rejected by variable validation in `infra/terraform/github/variables.tf`.
3. **Split rulesets**: `foodsavr-release-channels-integrity` has zero bypass actors; `foodsavr-release-channels-pr-gate` allows bypass only for repository admins and `${OWNER}-${REPO}-release-gate` (never `${OWNER}-${REPO}-agent`).
4. **Scoped WIF service accounts**:
   - `github-deploy-live`: deployment write roles bound to `repository + branch + github_environment`, once per release channel in `deploy_branches` (from the manifest's `channels`; the test project binds `develop`, `daily` and `weekly` to `test`, the production project `stable` to `production`). `allow_preview_refs` is refused for `production`.
   - `github-telemetry-ro`: read-only telemetry/levels roles bound to `repository + telemetry_branch`.
5. **Worktree-safe local state**: Local state lives under XDG state home, never inside a git worktree.
