# FoodSavr Terraform Roots (ADR 0008)

Infrastructure is split into two independent Terraform roots with isolated state, providers, and credentials:

| Root | Scope | Provider | Entry point | State location |
| --- | --- | --- | --- | --- |
| `infra/terraform/github/` | Per repository | `integrations/github` (`~> 6.0`) | `scripts/infra/apply-github.sh` | `${XDG_STATE_HOME:-$HOME/.local/state}/foodsavr/terraform/<owner>/<repo>/github/terraform.tfstate` |
| `infra/terraform/gcp/` | Per Firebase/GCP environment | `hashicorp/google-beta` (`~> 7.0`) | `scripts/infra/apply.sh` | GCS bucket on Blaze; `${XDG_STATE_HOME:-$HOME/.local/state}/foodsavr/terraform/<owner>/<repo>/gcp-<project>-<env>/terraform.tfstate` on Spark |

## Security invariants

1. **No secret values in state**: Terraform manages only non-secret identifiers and IAM bindings. Secrets are synced statelessly via `scripts/secrets/rotate.py`.
2. **No live kill-switch overrides**: Operational toggles (`FIREBASE_HOSTING_ENABLED`, `AUTO_HEAL_ENABLED`, `AUTO_HEAL_MERGE`, `TELEMETRY_POLL_ENABLED`, `MONITOR_TARGET_URL`) are rejected by variable validation in `infra/terraform/github/variables.tf`.
3. **Split rulesets**: `foodsavr-release-channels-integrity` has zero bypass actors; `foodsavr-release-channels-pr-gate` allows bypass only for repository admins and `${OWNER}-${REPO}-release-gate` (never `${OWNER}-${REPO}-agent`).
4. **Scoped WIF service accounts**:
   - `github-deploy-live`: deployment write roles bound to `repository + deploy_branch + github_environment`.
   - `github-telemetry-ro`: read-only telemetry/levels roles bound to `repository + telemetry_branch`.
5. **Worktree-safe local state**: Local state lives under XDG state home, never inside a git worktree.
