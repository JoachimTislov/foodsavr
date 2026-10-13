# ADR 0003: Autonomous agent execution boundary

## Status

Accepted (explicit owner intent, recorded on #213)

## Context

The sync loop (#213) and task sessions previously defaulted to asking the owner before acting. The owner has stated the goal: **remove the need for owner approval**. Agents must know exactly where autonomy ends so the loop can run continuously without waiting on a human, without ever risking irreversible damage.

## Decision

Agents act **without prior approval** on **revertable actions**:

- Creating/committing to non-protected task branches and `vibe/*` branches
- Docs/spec edits within the sync rules (#213) and ADR 0002
- Opening, updating, marking ready, and re-pushing task PRs (including `--force-with-lease` after a session's own history rewrite)
- Running CI, monitoring checks, and pushing focused fixes for failures — repeatedly, until green or a clear blocker
- Creating issues/comments that record work (not customer-visible notifications)

Agents **must still stop and ask** for non-revertable or high-risk actions:

- Protected/default branch writes, branch deletions, force-pushes to branches the session did not create
- Publishing packages, deployments, production/staging config, migrations
- Secrets, credentials, or anything secret-like
- Customer-visible notifications, paid jobs, load tests

Within a session, the stop conditions of #213 apply unchanged: when all domains are synced, the loop stops and awaits instructions. Autonomy governs **how** work is done, not whether the loop should keep inventing work.

## Consequences

- The owner's only required inputs are new intent (new specs per ADR 0002) and the rare high-risk approvals listed above.
- Draft-by-default PRs become ready-by-default for autonomous sessions; drafting remains available for speculative work.
- Sessions must still report what they did (PR/issue comments, ledger entries) — autonomy removes approval gates, not visibility.
