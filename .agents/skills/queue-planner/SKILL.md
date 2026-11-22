---
name: queue-planner
description: Plan the next batch of parallel implementation lanes from the open backlog and in-flight PRs, with file ownership, stacking, and integration order, published as a queue issue. Use when asked what to work on next, to plan or queue work for several parallel agents, or to record a finished batch's conflicts.
metadata:
  audience: agent
---

# Queue planner

Turn the open backlog into a **batch**: a set of **lanes** that agents implement in parallel and the merge gate integrates without any lane blocking another. A lane is one issue (or one explicit part of it), one worktree branch, one PR, and an exclusive **footprint** (the file regions it may change). The tracker, labels, and queue operations are configured in [.agents/tracker.md](../../tracker.md); blocking edges and the **frontier** mean what they mean in `to-tickets` and `wayfinder`; seam and prefactor vocabulary comes from `codebase-design`.

Planning writes only tracker records and a log event. Implementation, labels such as `triage/ready-for-agent`, and `merge/auto` stay with the owner and the implementing lanes.

## 1. Snapshot

Collect, paginating every list:

- Open issues with bodies, labels, parent epic, and native edges (`issue_dependencies_summary`, per tracker.md).
- Open PRs with base, head, draft state, linked issue, and footprint (`gh pr diff <n> --name-only`, then the hunk ranges of every hot file from `gh pr diff <n>`).
- The previous queue issue (label `queue:batch`): its carry-over lanes and retro.
- [references/hot-files.md](references/hot-files.md): the hot-file registry and seam conventions.

Done when every open PR has a footprint and every open issue has a parent, edges, and labels recorded.

## 2. Lock

Every file region in an open PR's footprint is **locked** until that PR merges. A candidate may build on a locked region only by **stacking** on that PR. Stack depth is at most 1: the parent PR targets `develop`, so nothing stacks on an already stacked PR.

## 3. Filter to candidates

An issue is a candidate only when all hold:

- Every blocker is merged, or the lane stacks on the blocker's open PR within the depth limit.
- It needs no pending owner decision: decision issues (ADR 0002), new spec concepts, and anything ADR 0003 makes stop-and-ask (secrets, deployments, migrations, rules deployment) stay with the owner.
- It fits one fresh context window. A larger issue enters only as an explicit part with its own acceptance subset (the PR then says `Part of #N`), or is left for `to-tickets`.
- No open PR already implements it.

Record each rejected issue with its one-line reason; the queue issue lists them as deferred.

## 4. Footprint each candidate

From the issue's evidence (it cites files and lines) and a quick read of the code, list the files and regions (symbol or line range) the work will change, including tests, translations, DI, schemas, specs, and dependencies. Mark every file that appears in the registry or in another candidate's footprint. Done when each candidate has a footprint concrete enough to name its owner region in every shared file.

## 5. Resolve conflicts

Two lanes in one batch never share a file region, and no lane touches a locked region, unless it is stacked on the owner. For each overlap, in this order:

1. **Seam convention**: a shared seam listed in the registry (translations, DI, spec status tables, shared test fakes, dependency manifests) is split by its convention, and each lane is assigned its slot (a translation namespace and anchor, an append slot, one owning lane).
2. **Prefactor first**: when two or more candidates need the same seam change, schedule that change as its own lane in this batch and defer the dependents to the next, or file a prefactor issue (with `issue-creator`, blocking the dependents through native edges).
3. **Stack**: when one candidate genuinely builds on another's code, stack it within the depth limit.
4. **Defer**: otherwise the lower-priority candidate waits for the next batch.

Prioritise among candidates: bugs with `risk/security`, then frontier work that unblocks the most issues, then issues that free hot seams, then the rest. Done when the footprints of the chosen lanes are pairwise disjoint per region.

## 6. Shape the batch

- Four to six lanes, at most one stacked lane per parent PR, base `develop` unless stacked.
- Each lane names: issue, branch (`issue-<n>-<slug>`), base, blockers, owned regions, seam slots, out-of-footprint files it must leave alone, and a model and effort suggestion (larger or security work takes the stronger model and higher effort).
- Integration order: the merge gate merges the lowest-numbered ready `merge/auto` PR first (ADR 0006), so order lanes by blockers, then smallest blast radius; when the planned order differs from PR numbers, the owner labels one PR at a time.
- Owner actions: every step only the owner can take (decisions, rules deployment, secrets, `merge/auto`, `triage/ready-for-agent`), with the issue or PR it unblocks.

Each implementing agent gets the lane brief from [references/queue-issue.md](references/queue-issue.md#lane-brief).

## 7. Publish

1. Create the queue issue from [references/queue-issue.md](references/queue-issue.md#queue-issue): title `Queue: batch N - <theme>`, label `queue:batch`.
2. Add native blocked-by edges and cross-links the plan revealed; leave other issue content unchanged.
3. Log it: `scripts/agents/agentctl log 'queue: batch N planned (<lanes>)' --issue '#<queue issue>'`.

## 8. Feed back

When the batch's lanes are merged or carried over, comment a retro on the queue issue: actual rebase conflicts (file, lanes), stack pain, duplicated hunks, and lanes that left their footprint. Update [references/hot-files.md](references/hot-files.md) with new hot files and conventions in the next queue PR, close the queue issue, and log `queue: batch N closed`.
