---
name: commit
description: Commit repository changes with FoodSavr conventions. Use whenever you create a git commit.
metadata:
  audience: agent
---

# Commit

1. Confirm the branch is not `main` (`git branch --show-current`). Source-code changes belong in a worktree branch (`make worktree name=<issue>`); the main working folder is reserved for meta tasks (agents, docs, research).
2. Review `git status` and `git diff`; stage only the task's files. Formatting and lint fixes go in the same commit as the change they follow.
3. For code changes, `make check` is green. After two consecutive failures, stop and report (headless: record the blocker in the ledger and the run result).
4. Write a Conventional Commit subject (`type(scope): summary`, for example `fix(router): handle auth redirect`) and a body giving the one- or two-line reason for the approach.
5. End the message with trailers:
   - `Agent-Session: <harness>:<session-id>`, the ID registered with `scripts/agents/agentctl sessions register`. This trailer links the commit to its session: `scripts/agents/agentctl sessions commits <harness>:<session-id>`.
   - The co-author trailer your harness requires.
6. Commit, then log the event in [.agents/ledger.md](../../ledger.md) and add the SHA to the session record (`sessions register --session-id ... --commit <sha>`; records upsert).
7. Push after each completed task (`make push`), unless the user asked otherwise.
