---
name: setup-system
description: Reproducible, fork-safe FoodSavr setup and onboarding orchestrator. Use when setting up FoodSavr on a new clone, a contributor fork, a new GitHub repository, or configuring GitHub rulesets, Apps, secrets, and Firebase/GCP WIF.
metadata:
  audience: agent
---

# Setup System (`setup-system`)

Governing principle (ADR 0008): **humans make decisions, agents make it possible**.

Never ask the user to type repository names, URLs, variable names, or raw Terraform commands when auto-discovery can derive them. Never execute irreversible cloud, GitHub, or secret writes yourself (ADR 0003).

## Authority boundary

| Allowed for agents (run directly) | Human-only (hand over exact copy-paste commands) |
| --- | --- |
| `python3 scripts/setup/setupctl.py probe -o json` | `python3 scripts/setup/setupctl.py fork --upstream ... --yes` |
| `python3 scripts/setup/setupctl.py scaffold-local ...` | `python3 scripts/setup/setupctl.py ensure-branches ... --yes` |
| `python3 scripts/setup/setupctl.py plan --write-dir .agents/state/setup -o json` | `scripts/human/github/create-agent-app.sh --role agent\|release-gate --repo ...` |
| `scripts/infra/apply-github.sh plan` (read-only) | `scripts/infra/apply-github.sh apply` |
| `scripts/infra/apply.sh plan` (read-only) | `scripts/infra/apply.sh apply` |
| `python3 scripts/setup/setupctl.py verify --profile ... -o json` | `scripts/secrets/rotate.py --repo ... <SECRET_NAME>` |
| `scripts/agents/agentctl status` & `scripts/agents/agentctl usage` | `gh api -X PUT repos/<owner>/<repo>/actions/permissions -F enabled=true` |

## Procedure

### 1. Probe first (never ask cold)

Run the read-only probe before asking the user anything:

```bash
python3 scripts/setup/setupctl.py probe -o json
```

Extract:
- `tools` (installed vs. missing CLIs)
- `github.login`, `github.target_repo`, `github.is_admin`, `github.needs_fork`
- `github.rulesets_supported` (automatically `false` on private GitHub Free repos)
- `github.branches`, `github.variables`, `github.secret_names`
- `local_files` (`dotenv`, `google_services`, `instance_local`, `hooks_configured`)

### 2. Collect minimal multiple-choice decisions

Ask only the decisions that cannot be inferred:

1. **Setup profile**:
   - `local-dev` — Zero cloud accounts or secrets; run Flutter app, emulators, and tests locally.
   - `fork-agents` — Own GitHub repo/fork + split rulesets + autonomous CI agent workflows (`agent-ops.yml`, `merge-gate.yml`).
   - `full-cloud` — Everything in `fork-agents` + Firebase/GCP Hosting + scoped WIF (`github-deploy-live` + `github-telemetry-ro`).
2. **Fork confirmation** (only when `github.needs_fork == true` and profile != `local-dev`):
   - Explain that GitHub Secrets are exclusive to the repository owner, so operating CI/agents requires forking to `<login>/foodsavr`. Confirm before planning the fork step.
3. **Release branch topology** (only when profile != `local-dev`):
   - `single` (Recommended for forks and personal setups) — `develop` only; deploys trigger on `develop` and the `release.yml` promote operation cleanly no-ops.
   - `two-stage` — `develop -> release`.
   - `full-channels` — `develop -> nightly -> beta -> stable -> release` (upstream FoodSavr default).
4. **Firebase billing plan** (only when profile == `full-cloud`):
   - `spark` (Recommended free tier; uses worktree-safe XDG local Terraform state).
   - `blaze` (Pay-as-you-go; requires a billing account and monthly budget alert in `deploy/instance.yaml`).

### 3. Execute all safe agent steps

1. Scaffold local files and hooks idempotently (preserves existing real config):
   ```bash
   python3 scripts/setup/setupctl.py scaffold-local \
     --profile <profile> --topology <topology> --repo <target_repo>
   ```
2. Generate the deterministic plan and non-secret `.tfvars`:
   ```bash
   python3 scripts/setup/setupctl.py plan \
     --profile <profile> --topology <topology> --firebase-plan <spark|blaze> \
     --write-dir .agents/state/setup -o json
   ```
3. If `github.is_admin == true` and `terraform` is installed, preview read-only plans:
   - `GITHUB_REPOSITORY=<repo> RELEASE_TOPOLOGY=<topology> TFVARS_FILE=.agents/state/setup/github.tfvars scripts/infra/apply-github.sh plan`
   - (For `full-cloud`) `ENV=production RELEASE_TOPOLOGY=<topology> scripts/infra/apply.sh plan`

### 4. Hand off exact human commands

Present `plan.human_actions` in order with their exact copy-paste commands. Remind the human:
- Never paste secret values into chat; `scripts/secrets/rotate.py` and `scripts/human/github/create-agent-app.sh` read hidden TTY input or local files directly.
- On a new fork, enable GitHub Actions **last** (after vars and secrets are synced) so scheduled workflows do not fire unconfigured.
- Configure 2+ CI harness logins (`CLAUDE_CODE_OAUTH_TOKEN`, `CODEX_AUTH_JSON_B64`, `ANTIGRAVITY_OAUTH_TOKEN_B64`, `GEMINI_API_KEY`) to enable automatic quota-aware failover (`agentctl usage`).

### 5. Verify zero drift

Once the human reports completion, verify end-to-end:

```bash
python3 scripts/setup/setupctl.py verify --profile <profile> --topology <topology> -o json
scripts/agents/agentctl status
```

Report any remaining `MISS` items with their exact remediation command.

The checks are declared in `scripts/setup/health.toml` and evaluated by `scripts/setup/health.py` (ADR 0008, November 27 amendment). If you verify something by hand (curl a site, read a run log, compare variables), add it there as a `[[check]]` in the same change so it is never checked by hand again. Keep the domain CLIs; health calls their `--check` modes.
