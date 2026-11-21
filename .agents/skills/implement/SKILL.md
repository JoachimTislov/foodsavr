---
name: implement
description: Implement an issue, ticket, or spec end to end. Use when asked to build work from an issue, a set of tickets, or a spec, including `triage/ready-for-agent` issues picked up by a runner.
metadata:
  audience: agent
---

# Implement

The issue tracker is configured in [.agents/tracker.md](../../tracker.md). Fetch any referenced issue and state its title before starting; when a reference is ambiguous, ask, or in a headless run record the blocker and stop.

Pick the mode from the work:

- **One ticket or issue** → build it here.
- **A spec whose tickets form a task graph** → orchestrate (below).

## One ticket

1. Work in a worktree branch, never `main` (`make worktree name=<issue>`).
2. Load `flutter-standards` for Dart work. Build with `tdd` at the seams the ticket names; when it names none, pick the highest existing seam and state it.
3. Run single test files while working and `make check` at the end.
4. Review with `code-review` against the branch base; fix its findings.
5. Commit with `commit`; open the PR with `pr` when the tracker closes work through PRs.

## Spec with tickets

The goal is the whole spec on one **integration branch**, every ticket resolved the way the tracker closes work. Tickets are a **task graph** with blocking edges; the **frontier** is every ticket whose blockers are done.

1. Read the spec and tickets to build the graph.
2. Optional: an exploration subagent saves notes outside the repo for the implementers to read.
3. Create the integration branch. Open a draft PR after the first merge (step 5), marked as closing the spec and tickets.
4. Start a fresh implementer subagent per frontier ticket, each in its own worktree branched from the integration branch, running the one-ticket steps 2–3 and merging the integration tip into its branch before reporting.
5. Merge each finished ticket into the integration branch with a merger subagent; start implementers for newly unblocked tickets.
6. When all tickets are done, run `code-review` on the integration branch and fix its findings in one fresh implementer.
7. Mark the draft PR ready, or report the integration branch; remove implementer worktrees.

Communicate with subagents through context pointers (spec, ticket, notes, commits), not copies.
