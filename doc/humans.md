# For humans

Run `make setup`.

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
- `make setup LIST=1` shows what is still missing from your setup.
- GitHub pull requests and Actions show work in flight and CI results.
- [Implementation status](../specs/source-of-truth/status.md) shows what is built versus planned.
