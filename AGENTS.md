# Agent Instructions

Before changing code or documentation, read [specs/source-of-truth/INDEX.md](specs/source-of-truth/INDEX.md) and follow its sync process.

## User preferences

- Be minimal. Write nothing beyond what the user strictly needs to know.
- Always log events (what was changed, committed, pushed, replied) when doing repo work.
- Historical repository events are recorded in [.agents/ledger.md](.agents/ledger.md); read it only when historical context is needed.

## Source of truth & sync rules

- `specs/source-of-truth/` is the canonical spec (#212). Where root docs (`README.md`, `INDEX.md`, `TODO.md`, `doc/`) conflict with it, it wins; the conflict is a sync finding.
- Shaped artifacts (`schemas/`, `registries/`, `contracts/`) are authoritative where they exist; Markdown points at them, never duplicates them (ADR 0004).
- Before doing repo work, consult `specs/source-of-truth/status.md` for domain sync state.
- Sync sessions: docs-only writes, no new concepts, contract-first authority (if the code is correct, the spec is updated). Full rules in #213; shape drift is caught in CI by `scripts/ci/check_shape_sync.dart`.
- New specs/sections/shapes require explicit owner intent, agreed before edits (ADR 0002).
- Autonomous execution boundary per ADR 0003 (`specs/source-of-truth/decisions/0003-autonomous-execution-boundary.md`).

