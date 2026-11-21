---
name: pr-merge-coordinator
description: Prioritize the repository's open PRs against a user's objective, coordinate with local and CI agent sessions, and merge finalized PRs in dependency order. Use for a mixed-readiness PR queue or stack; an individual green-check notification is not an instruction to merge unrelated work.
---

# PR merge coordinator

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
Align scope, research, and merge ownership with that coordinator. When none
is running and reachable, use the peer protocol in the coordination reference.

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
- Required reviews are satisfied; inspect review threads and material
  objections, including feedback not represented by approval status.
- Dependencies landed in the intended destination, mergeability is known,
  and branch/environment protection and any deployment authorization allow
  the merge. A stack PR green against a feature branch is not thereby ready
  to land on the default branch.

Seek a revision-bound handoff from a session actively editing or reviewing
the affected PR. Respect holds and permissions. Report an unreachable active
owner as a blocker for that PR, then advance independent work. Historical
authorship alone does not require approval from an idle former author.

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
pending. Apply the host's PR-linking rules to each PR taken over.

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
