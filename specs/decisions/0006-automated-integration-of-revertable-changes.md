# ADR 0006: Automated integration of revertable changes

## Status

Accepted (explicit owner intent, 2026-11-21: "reliable automated integration of revertable changes"; "quick feedback loop, pro-actively running the required commands locally"). Amended by [ADR 0007](0007-develop-integration-branch-and-fast-forward-deploy.md): integration targets `develop`, expensive checks are gated in the `merge/auto` queue, and `main` is updated via scheduled/manual fast-forward promotion.

## Context

Integration depended on agents cooperating: the pr-merge skill can order and merge a queue, but nothing invoked it, so finalized PRs sat `BEHIND` under the strict up-to-date rule. Pushing to find out whether CI passes made feedback slow and noisy. ADR 0003 also required asking before any default-branch write.

## Decision

### Opt-in and trusted-author gate

The `merge/auto` label means: the task's acceptance is met, review feedback is addressed, the PR is a two-way door (PR template **Door**), and the author hands the branch to the merge gate. Removing the label is the hold. Dependabot patch/minor bumps are opted in automatically unless the label was removed before; major bumps need an explicit opt-in.

Amendment (2026-11-25): `merge/auto` is also the trigger for the full `Validation` run. Human-merge PRs (`risk/security`, security paths, one-way doors) therefore carry it once finalized too. The gate still refuses to merge or update them, and the human rebases and merges.

Auto-merging and Dependabot auto-opt-in apply **only to trusted authors** on same-repository branches: non-fork PRs opened by `OWNER`, `MEMBER`, or `COLLABORATOR` humans, or allowlisted bots (`dependabot[bot]`, `github-actions[bot]`, and configured `AGENT_APP_SLUG`). Fork PRs, external contributors (`NONE`, `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`), and unallowlisted bots are always blocked even if `merge/auto` is applied.

### The merge gate owns integration of opted-in PRs

`.github/workflows/merge-gate.yml` runs `scripts/github/merge_gate.py` on CI completion, PR readiness (`opened` when non-draft, `ready_for_review`), `merge/auto` labeling, pushes to `main`, and a 30-minute schedule (ignoring forks). Each run reconciles the whole queue (level-triggered) and:

1. merges the oldest opted-in trusted PR that is up to date with **every** check on its head green (`CLEAN` and rollup `SUCCESS`, not only required checks), with no changes requested, no unresolved or truncated (`>100`) review threads, no one-way-door declaration, and a passing head-bound review attestation at `>= required_tier` (`scripts/github/pr_review.py`); rebase method, bound to the verified head SHA;
2. otherwise, when no opted-in PR is running checks, updates the oldest `BEHIND` one: rebase onto `main`, or `@dependabot rebase` for Dependabot (never rewritten by the gate);
3. leaves blocked or untrusted PRs (conflicts, failures, missing/stale/under-tiered review, draft, fork, untrusted author, refused Dependabot rebase) to their authors, distinguishes `held` (`merge/auto` removed) and Dependabot major bumps from PRs `awaiting opt-in`, and reports them in the run summary.

One PR is in flight at a time, so each merged head is exactly what CI tested. Checks pending for over 60 minutes stop holding the queue. The gate acts as `MERGE_GATE_TOKEN` because merges and pushes made with `GITHUB_TOKEN` trigger no workflows (push CI, Pages, release candidates).

### Adaptive auto-review and post-merge bisect learning

`scripts/github/pr_review.py` and the review operation of `.github/workflows/agent-ops.yml` classify each PR into an adaptive review tier (`exempt`, `fast`, `balanced`, `deep`, or `human`) aligned with `.agents/runners/router.json` and the dual-axis `code-review` skill (Standards + Spec). Prior `incident` records in `.agents/reviews/history.jsonl` matching the PR's files, areas, or risk signatures automatically escalate `required_tier` (e.g. from `fast` or `balanced` to `deep`, or from `deep` to `human`) and surface recommended static checks. When a post-merge regression occurs, `pr_review.py bisect-learn` runs a two-stage `git bisect` (`--first-parent` across merges on `main`, then across the culprit PR's feature-branch commits) and records a new `incident` entry so future changes to that area automatically receive deeper review.

### Local CI mirror before pushing

`scripts/ci/local_ci.py` runs the CI checks for the areas a branch changes, through a pre-push hook (`make hooks`). Agent-system and documentation CI call the same script; the Dart group is kept equal to `Check & Test` in `pull-request.yml` and uses CI's pinned Flutter version. Checks that need CI infrastructure (smoke, E2E, integration, rules, dependency review) remain CI-only.

### Amends ADR 0003

Merges of opted-in PRs by the merge gate are autonomous. Other default-branch writes keep ADR 0003's boundary.

## Consequences

- Authors' only integration step is the label; ordering, updating, and merging need no coordinating session.
- Every merged head carries an auditable review attestation at its risk-adjusted tier, and post-merge regressions automatically harden future review requirements for affected paths.
- An author resuming work removes the label first and fetches, since the gate may have rebased the branch.
- Integration halts visibly (failed gate runs) when `MERGE_GATE_TOKEN` is missing or expired.
- Merges of application code start the existing release-candidate pipeline, as owner-configured; a revert produces a new candidate.
