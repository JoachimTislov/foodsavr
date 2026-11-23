# For humans

You steer; agents and scripts run the system. This page lists only what needs you. Everything else is automated and documented in the scripts, skills, and [specification](../specs/source-of-truth/INDEX.md), not here ([ADR 0011](../specs/source-of-truth/decisions/0011-human-docs-cover-manual-processes-only.md)).

## Start

1. Clone the repository: `git clone https://github.com/JoachimTislov/foodsavr.git`.
2. Ask an agent in the clone to run `make setup`. It probes your machine and GitHub, scaffolds local files, previews plans, and hands you the commands below that only you can run.
3. Run only those commands. Without an agent, `make setup` runs the same guided wizard.

## Manual processes

Run `make human`. It shows what is missing, then lists every manual process (setup, infrastructure, secrets, the sign-in wizards) and every manual bypass of the automated pipeline (merge a PR, validate a branch, promote a channel, deploy the site), and runs the one you pick. `make human LIST=1` prints the same menu as text.

One step has no script: enable Anonymous sign-in in the Firebase console, **Authentication**, **Sign-in method**.

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
