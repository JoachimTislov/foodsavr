---
name: docs-writer
description: Write and edit human-facing FoodSavr documentation. Use when changing `README.md`, `INDEX.md`, `TODO.md`, `doc/`, `docs/`, or `specs/` prose.
metadata:
  audience: agent
---

# Docs writer

Documents agents consume (skills, `AGENTS.md`, pointed-at agent docs) follow `writing-for-agents` instead.

## Authority

1. Read [specs/INDEX.md](../../../specs/INDEX.md) and `status.md`. The spec is authoritative; `README.md`, `INDEX.md`, `TODO.md`, and `doc/` are derived, and a conflict is a sync finding, resolved in the spec's favour.
2. Shaped artifacts (`schemas/`, `registries/`, `contracts/`) own their facts: point at them, never restate them (ADR 0004).
3. New specs, sections, or shapes need explicit owner intent first (ADR 0002). Sync sessions write docs only and add no concepts.
4. Verify every claim against the code before writing it.

## Style

- Address the reader as "you"; active voice, present tense; plain US English, no idioms or hype.
- "Must" for requirements, "we recommend" for advice.
- Sentence-case headings, each followed by an overview sentence before lists or sub-headings.
- Numbered lists for sequential steps, each starting with an imperative verb, conditions before instructions; bullets otherwise.
- `code font` for files, commands, and identifiers; **bold** for UI elements; descriptive link text.
- Unambiguous dates ("November 21, 2026"); "for example" and "that is" instead of Latin abbreviations.
- No table of contents.

## Finish

1. Check every new or changed link and the pages that link to what changed.
2. Run `make check` when Dart or generated docs changed; `scripts/agents/agentctl heal` validates agent docs.
3. Log the change in the ledger; record sync-session results in the spec's `status.md` sync ledger.
