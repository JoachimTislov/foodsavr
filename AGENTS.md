# Agent Instructions

Before changing code or documentation, read [specs/source-of-truth/INDEX.md](specs/source-of-truth/INDEX.md) and follow its sync process.

## User preferences

- Be minimal. Write nothing beyond what the user strictly needs to know.
- Always log events (what was changed, committed, pushed, replied) when doing repo work.
- Historical repository events are recorded in [.agents/ledger.md](.agents/ledger.md); read it only when historical context is needed.
- Provider session IDs and searchable session metadata are recorded in [.agents/sessions/index.jsonl](.agents/sessions/index.jsonl); use `scripts/agents/agentctl context "..."` before starting from an ambiguous prior session.

## Source of truth & sync rules

- `specs/source-of-truth/` is the canonical spec (#212). Where root docs (`README.md`, `INDEX.md`, `TODO.md`, `doc/`) conflict with it, it wins; the conflict is a sync finding.
- Shaped artifacts (`schemas/`, `registries/`, `contracts/`) are authoritative where they exist; Markdown points at them, never duplicates them (ADR 0004).
- Before doing repo work, consult `specs/source-of-truth/status.md` for domain sync state.
- Sync sessions: docs-only writes, no new concepts, contract-first authority (if the code is correct, the spec is updated). Full rules in #213; shape drift is caught in CI by `scripts/ci/check_shape_sync.dart`.
- New specs/sections/shapes require explicit owner intent, agreed before edits (ADR 0002).
- Autonomous execution boundary per ADR 0003 (`specs/source-of-truth/decisions/0003-autonomous-execution-boundary.md`).


## Dependabot PRs

For Dependabot PR updates, read the
[PR merge skill](.agents/skills/pr-merge/SKILL.md#dependabot-pr-updates).

## Secrets

- Create, rotate or set secrets (GitHub Actions secrets, `.env` keys) only through `scripts/secrets/rotate.py NAME [NAME ...]`; never call `gh secret set` or edit secret values in `.env` directly.
- Register every new secret in `scripts/secrets/registry.toml` (generator, effort, groups, public, sinks, hint) in the same change that introduces it. Never put values in the registry, code, logs, or commits.
- Any leak means rotation, without waiting for approval: rotate the leaked secret's whole group (`--group NAME` or `@NAME`), since secrets stored together leak together. Give every new secret the groups of the places it is stored.
- `effort` (low | high) describes how complex or time-consuming renewal is, never leak severity. Outside a leak, rotate only what the task needs; `--low-effort` handles routine bulk rotation. Use `--dry-run` to preview.
- Values shipped in clients by design (bundled `.env`, Firebase client config, Facebook app ID/client token) are not leaked by being visible there; mark them `public = true`.
