# Agent knowledge catalog

Git-tracked Markdown, shaped specifications, and JSONL records remain the
auditable source layer. SQLite is a local, disposable query projection over
that layer. It is not committed and never becomes the authority for domain
decisions.

The projection combines repository documents, extracted issue/PR/commit/URL
references, provider session metadata, workflow run status, event types, patch
artifact hashes, and FTS5 full-text search. Rebuild it after a checkout or
source change:

```sh
scripts/agents/agentctl knowledge rebuild
```

Query it from any harness:

```sh
scripts/agents/agentctl query "FoodSavr TODO"
scripts/agents/agentctl context "current app status and open work"
scripts/agents/agentctl sessions list
scripts/agents/agentctl query "repository-health run-"
scripts/agents/agentctl runs list repository-health
scripts/agents/agentctl runs show <run-id>
```

`runs list` and `runs show` expose bounded run metadata, artifact hashes, and
event types. They never return the raw provider result or transcript, so a
harness can inspect execution state without injecting sensitive payloads into
the next prompt.

The database lives at `.agents/state/knowledge.sqlite3` and is ignored. CI or
a provider adapter can rebuild it from the checkout, so stale database files
are never merged as authority.

## Why SQLite

JSONL remains the append-friendly event format for session records. SQLite is
the better query layer because it provides relational links, transactions,
indexes, provider-specific JSON storage, and FTS5 ranking without a service.
A graph database is unnecessary at this scale: `references`,
`session_references`, and the workflow-run artifact/event tables provide
graph-like traversal through normal SQL joins.

This design is intentionally a projection rather than a migration that deletes
`doc/`. Removing Markdown would break provider-native context loading and make
Git history harder to review. The relational store indexes `doc/`, `docs/`,
`specs/`, root entrypoints, and `.agents/` while preserving those files as the
editable source layer.

Markdown remains because agents and provider runtimes consume it directly,
Git reviews it well, and it is the durable human-readable projection. The
database is rebuilt, never hand-edited.
