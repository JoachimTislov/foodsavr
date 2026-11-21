---
name: pr-merge
description: Prioritize the repository's open PRs against a user's objective, coordinate with local and CI agent sessions, and merge finalized PRs in dependency order. Use for Dependabot PR updates and to assess and merge PRs, including mixed-readiness queues and stacks, within the requested scope.
metadata:
  audience: agent
---

# PR merge

Turn the current PR queue into an ordered plan and execute its authorized,
ready portion. A blocked parent, active author, or uncertain PR blocks the
affected work; continue with independent ready PRs.

Writing or installing this skill does not execute it. On invocation, derive
merge authority from the user's request and repository rules. A request to
categorize or report stays read-only. A request to merge authorizes finalized
PRs within its scope; retain any applicable repository approval boundaries.

## Establish the queue

Read repository instructions and canonical status. Resolve the repository,
target branches, user's objective, exclusions, urgency, and existing merge
authorization from the invocation and session. Discover the available main
agent, orchestrator, or conductor before starting independent investigation.
Align scope, research, and merge ownership with that coordinator, including
one waiting for CI, delegated work, or watch events. Use the peer protocol
when no coordinator retains the scope; an unreachable owner leaves its
affected scope blocked pending handoff.

Enumerate **all open PRs**, paginating rather than accepting the CLI default
limit. Inspect linked issues, actual diffs, base/head SHAs, dependencies,
draft status, checks, review threads, merge policy, deployments triggered by
merge, and active authorship. Read relevant closed/merged prerequisites too.
Green checks are one input: verify the originating task's acceptance criteria
and distinguish an intentional phase boundary from unfinished promised work.

Read [Session coordination](references/coordination.md) before contacting
owners or mutating a PR. Complete discovery when every open PR has a category,
readiness state, owner assessment, and evidence or an explicit unknown.

## Categorize and order

Keep relevance separate from readiness. Show a compact queue with these fields:

| Field | Record |
|---|---|
| PR and head | URL and observed SHA |
| Relevance | Required prerequisite, directly advances objective, supporting, unrelated, or superseded candidate |
| Readiness | Ready, author working, awaiting checks/review, blocked, or needs human decision |
| Dependency/owner | Parent/base, blockers, session/run, and any handoff agreement |
| Next action | Merge order or the concrete condition needed to proceed |

Prioritize prerequisites before dependents, then direct relevance, then
supporting work. Use impact and risk to break ties; PR number and green CI
alone do not determine priority. Hold unrelated work unless the invocation
covers it. Flag redundant PRs for a decision rather than closing them as part
of categorization. Show the proposed order before mutating; continue without
a ceremonial confirmation when the request and evidence already authorize it.

Route ambiguity about intent, competing implementations, consequential
behavior, or ownership to the available coordinator first, with evidence and
the exact decision needed. Align any further research with that agent rather
than sending duplicate questions to the human. Without a coordinator, resolve
it with affected peers; ask the human only when evidence and delegated
authority cannot settle the decision. Continue independent work while waiting.
A human's agreement applies to the stated scope and revision; material changes
reopen that choice through the same coordination path.

## Coordinate and establish readiness

A PR is ready only when all applicable conditions hold:

- Its scope satisfies the agreed task or explicit phase, it is open and
  finalized, and there is no unresolved author hold or competing writer.
- Required checks and meaningful task-specific validation passed for its
  current head and relevant base/merge result. Explain skipped or absent
  checks; missing validation is not passing validation.
- Required reviews are satisfied; inspect human inline review comments,
  review threads, and material objections, including feedback not represented
  by approval status. Address each requested change or record an explicit
  owner decision before marking the PR ready.
- Dependencies landed in the intended destination, mergeability is known,
  and branch/environment protection and any deployment authorization allow
  the merge. A stack PR green against a feature branch is not thereby ready
  to land on the default branch.

Seek a revision-bound handoff from a session actively editing or reviewing
the affected PR. Respect holds and permissions. Report an unreachable active
owner as a blocker for that PR, then advance independent work. Historical
authorship alone does not require approval from a former author whose task
is finished or handed off. An idle run awaiting events still retains its work.

## Merge gate

The merge gate workflow (ADR 0006) owns integration of PRs labeled
`merge/auto`: it serializes updates and merges without an invoking session.
Treat those PRs as owned by the gate; do not merge, rebase, or request
rebases for them yourself. To take one back, remove the label. Use this skill
for PRs outside the gate: triage, one-way doors, stacks, and owner-scoped
merges. Read the gate's latest run summary when assessing the queue.

## Dependabot PR updates

To update a Dependabot PR, post `@dependabot rebase` in a PR comment, then
wait for the bot to update the head and CI to finish. If the bot refuses or
cannot update the PR, report the blocker. Never manually rebase, force-push,
or otherwise rewrite or update a Dependabot branch. Preserve explicit owner
intent; a bot refusal does not authorize a workaround. Reassess readiness
against the bot-updated head before merging.

## Execute the ready portion

Serialize merges affecting the same base or stack. Immediately before each
merge, re-read head/base, checks, reviews, owner updates, and mergeability.
Invalidate readiness after a new commit, base change, or new material hold.
If another coordinator is active, agree which session owns the merge; a
ledger entry or comment alone is not an atomic lock.

Use the repository's allowed merge method and queue. Where supported, bind
the operation to the reviewed head, for example:

```sh
gh pr merge <PR_URL> --squash --match-head-commit <VERIFIED_HEAD_SHA>
```

Choose `--squash` only when allowed by repository policy. Respect the merge
queue and protection checks; bypass flags are outside this workflow. Preserve
branches and worktrees used by other sessions. Confirm the server reports
`MERGED` and record its resulting SHA; a queued or auto-merge request is still
pending. Keep a named owner and actionable handoff until it completes. If a
hold or authorization change arrives, the owner must remove the PR from the
merge queue and disable auto-merge wherever enabled, then confirm the server
has withdrawn those pending requests. If withdrawal fails, notify the
coordinator immediately and retain the blocker until server state is known.
Apply the host's PR-linking rules to each PR taken over.

After each merge, notify affected owners, refresh the remaining dependency
graph, and re-evaluate descendants. Retargeting a stack changes its diff and
validation context: coordinate with its owner, check the resulting scope,
and wait for relevant checks/reviews before merging the next layer. Make
small authorized fixes yourself; agree ownership before changing another
session's branch. Avoid rebasing, force-pushing, cancelling runs, or replacing
an author's work without the required handoff and authorization.

## Wait or finish

Use event-driven PR/session notifications when available. Follow the host's
watch lifecycle and end the turn when it requires that. Headless runners use
an authenticated inbox only if actually supported; otherwise leave a durable
handoff and a precise resume condition. Do not keep a runner alive with an
unbounded polling loop. Re-read live state after every wake.

Log classifications that affected decisions, agreements, edits, pushes,
messages, merges, and blockers using repository event/session conventions.
In CI, retain the handoff through an authorized PR/issue record or artifact;
local files disappear with the runner. Avoid committing log-only changes to
the protected branch outside the normal PR process.

Finish when every in-scope PR is confirmed merged or has a specific blocker,
owner, and resume condition, and every out-of-scope PR is accounted for.
Report merged PRs with SHAs, queued/waiting work, blocked/held work and why,
and any pending human decision. State partial completion plainly; do not
claim the objective is complete merely because the first PR is green.
