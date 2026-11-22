# ADR 0006: Automated integration of revertable changes

## Status

Accepted (explicit owner intent, 2026-11-21: "reliable automated integration of revertable changes"; "quick feedback loop, pro-actively running the required commands locally"). Amended by [ADR 0007](0007-develop-integration-branch-and-fast-forward-deploy.md): integration targets `develop`, expensive checks are gated in the `merge/auto` queue, and `main` is updated via scheduled/manual fast-forward promotion.

## Context

Integration depended on agents cooperating: the pr-merge skill can order and merge a queue, but nothing invoked it, so finalized PRs sat `BEHIND` under the strict up-to-date rule. Pushing to find out whether CI passes made feedback slow and noisy. ADR 0003 also required asking before any default-branch write.

## Decision

### Opt-in

The `merge/auto` label means: the task's acceptance is met, review feedback is addressed, the PR is a two-way door (PR template **Door**), and the author hands the branch to the merge gate. Removing the label is the hold. Dependabot patch/minor bumps are opted in automatically unless the label was removed before; major bumps need an explicit opt-in.

### The merge gate owns integration of opted-in PRs

`.github/workflows/merge-gate.yml` runs `scripts/github/merge_gate.py` on CI completion, labeling, pushes to `main`, and a 30-minute schedule. Each run reconciles the whole queue (level-triggered) and:

1. merges the oldest opted-in PR that is up to date with **every** check on its head green (`CLEAN` and rollup `SUCCESS`, not only required checks), with no changes requested, no unresolved current review threads, and no one-way-door declaration; rebase method, bound to the verified head SHA;
2. otherwise, when no opted-in PR is running checks, updates the oldest `BEHIND` one: rebase onto `main`, or `@dependabot rebase` for Dependabot (never rewritten by the gate);
3. leaves blocked PRs (conflicts, failures, review, draft, fork, refused Dependabot rebase) to their authors and reports them in the run summary.

One PR is in flight at a time, so each merged head is exactly what CI tested. Checks pending for over 60 minutes stop holding the queue. The gate acts as `MERGE_GATE_TOKEN` because merges and pushes made with `GITHUB_TOKEN` trigger no workflows (push CI, Pages, release candidates).

### Local CI mirror before pushing

`scripts/ci/local_ci.py` runs the CI checks for the areas a branch changes, through a pre-push hook (`make hooks`). Agent-system and documentation CI call the same script; the Dart group is kept equal to `ci-checks.yml` and uses CI's pinned Flutter version. Checks that need CI infrastructure (smoke, E2E, integration, rules, dependency review) remain CI-only.

### Amends ADR 0003

Merges of opted-in PRs by the merge gate are autonomous. Other default-branch writes keep ADR 0003's boundary.

## Consequences

- Authors' only integration step is the label; ordering, updating, and merging need no coordinating session.
- An author resuming work removes the label first and fetches, since the gate may have rebased the branch.
- Integration halts visibly (failed gate runs) when `MERGE_GATE_TOKEN` is missing or expired.
- Merges of application code start the existing release-candidate pipeline, as owner-configured; a revert produces a new candidate.
