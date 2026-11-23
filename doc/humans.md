# For humans

You steer; agents and scripts run the system. This page lists only what needs you. Everything else is automated and documented in the scripts, skills, and [specification](../specs/source-of-truth/INDEX.md), not here ([ADR 0011](../specs/source-of-truth/decisions/0011-human-docs-cover-manual-processes-only.md)).

## Start

1. Clone the repository: `git clone https://github.com/JoachimTislov/foodsavr.git`.
2. Ask an agent in the clone to run `make setup`. It probes your machine and GitHub, scaffolds local files, previews plans, and hands you the commands below that only you can run.
3. Run only those commands. Without an agent, `make setup` runs the same guided wizard.

## Manual processes

Each row is something an agent must not do for you (browser consent, console clicks, secrets, one-way changes).

| Process | Command |
| --- | --- |
| Fork upstream (contributors; GitHub secrets are owner-only) | `python3 scripts/setup/setupctl.py fork --upstream <owner>/foodsavr --yes` |
| Create missing channel branches | `python3 scripts/setup/setupctl.py ensure-branches --repo <owner>/<repo> --topology <topology> --yes` |
| Create the GitHub Apps | `scripts/human/github/create-agent-app.sh --role agent --repo <owner>/<repo>`, then again with `--role release-gate` |
| Apply rulesets, environments, labels, variables | `make infra-github-apply` |
| Apply the GCP and Firebase stack | `make infra-gcp-apply` |
| Log in the Firebase CLI for CI | `scripts/human/firebase/login-cli-token.sh` |
| Log in CI agent harnesses | `scripts/human/agents/login-claude-runner.sh`, `sync-codex-runner.sh`, `sync-antigravity-runner.sh` |
| Google sign-in client secret | `scripts/human/google/create-web-client-secret.sh`, `rotate-web-client-secret.sh` |
| Facebook sign-in credentials | `scripts/human/meta/create-app-credentials.sh`, `rotate-app-secret.sh`, then `make social-auth-setup` |
| Codecov upload token | `scripts/human/codecov/rotate-upload-token.sh` |
| Any other secret | `scripts/secrets/rotate.py NAME` (never `gh secret set` or editing `.env`; after a leak, rotate the whole group with `--group`) |
| Enable Anonymous sign-in | Firebase console, **Authentication**, **Sign-in method** (no script) |
| Enable GitHub Actions on a fork, last | `gh api -X PUT repos/<owner>/<repo>/actions/permissions -F enabled=true` |

Run `ls scripts/human/*/` for the current scripts; each header names what it does and why it needs you.

## Approvals and intent

- [ADR 0003](../specs/source-of-truth/decisions/0003-autonomous-execution-boundary.md): agents stop and ask before deployments, publishing, production configuration, migrations, secrets, rulesets, protected-branch writes, paid jobs, and customer-visible notifications.
- A PR marked **Door: one-way** needs your approving review.
- New specs, sections, or concepts need your stated intent first ([ADR 0002](../specs/source-of-truth/decisions/0002-intent-gated-specs-optimized-verification.md)).

## Steer

- Open an issue with the goal. The `triage/ready-for-agent` label hands it to an agent.
- State intent and constraints in the issue or PR; agents do not infer new scope.
- Add `merge/auto` to a finished two-way-door PR to let the merge gate integrate it. Remove it before you resume work on the branch, then fetch.
- Contributors outside the repository: see [CONTRIBUTING.md](../CONTRIBUTING.md).

## Live state

Docs drift; look at the system instead.

- `make agent-status` shows the agent system's health; `make agent-usage` shows harness quota headroom.
- `make setup-verify` shows what is still missing from your setup.
- GitHub pull requests and Actions show work in flight and CI results.
- [Implementation status](../specs/source-of-truth/status.md) shows what is built versus planned.
