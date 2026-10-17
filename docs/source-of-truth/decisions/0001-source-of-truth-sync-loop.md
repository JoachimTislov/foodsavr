# ADR 0001: Markdown source of truth with agent sync loop

## Status

Accepted (#212, #213)

## Context

Project knowledge is scattered across README.md, INDEX.md, TODO.md, AGENTS.md, `doc/`, issues, and code, with drift between them (#190 findings). Future work (foodsavr_core, MCP server) needs a single canonical spec that both humans and agents align against.

## Decision

- A `docs/source-of-truth/` folder of Markdown files is the canonical spec (#212).
- A standing sync loop (#213) runs vibe sessions that absorb code/docs state and align the folder with it: verifiable stop condition, contract-first authority (if code is correct, spec is updated), docs-only writes, no new concepts, and a replay ledger in `status.md` that forwards to git history rather than duplicating it.

## Consequences

- Where root docs conflict with this folder, this folder wins; the conflict is a sync finding.
- Spec-ahead statements are marked as such and are not "fixed" by sync sessions.
- New design work goes to #212 task issues, not to sync PRs.
