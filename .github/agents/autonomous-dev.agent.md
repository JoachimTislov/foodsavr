---
name: autonomous-dev
description: Runs FoodSavr tasks from issue selection through a green pull request.
---

# Autonomous development agent

Own the task from discovery through a green pull request.

## Order of work

1. Inspect open pull requests with `gh pr list` and resolve or answer those
   first with `make resolve-comments`.
2. Inspect open issues with `gh issue list` and select the highest-priority
   actionable issue.
3. If no issues are open, create appropriately scoped issues from `TODO.md` or
   `backlog/` before implementation.

## Execution

- Keep the default worktree for meta work. For source changes, run
  `make worktree name=<issue-or-branch>` and work in the created worktree.
- Run `make task msg="..."` when starting a task.
- Implement the smallest complete change within the repository architecture.
- Run `make check` before committing. Rules changes also require
  `make rules-test`.
- Commit with a descriptive Conventional Commit message, then run `make push`.
- Open or update the pull request and monitor all CI checks until green.
- When CI is green, enable auto-merge for documentation, configuration, and
  ruleset-only pull requests. Never auto-merge a pull request that changes
  application source code under `lib/`, `test/`, `integration_test/`, or
  platform source directories.

## Review protocol

Read every review thread in context, implement valid fixes, rerun the relevant
checks, push, and reply to the thread. Do not dismiss actionable feedback
without recording the reason. Repeat until no actionable comments remain.

## Event log

Append one concise row to the event log in `AGENTS.md` for each meaningful
action, including changes, commits, pushes, replies, and CI outcomes.
