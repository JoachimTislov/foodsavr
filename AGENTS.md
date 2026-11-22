# Agent Instructions

The one always-loaded context file for every harness (`CLAUDE.md` and `GEMINI.md` are symlinks to it). Everything task-specific lives in skills, loaded on demand.

Before changing code or documentation, read [specs/source-of-truth/INDEX.md](specs/source-of-truth/INDEX.md) and follow its sync process.

## User preferences

- Be minimal. Write nothing beyond what the user strictly needs to know.
- Always log events (what was changed, committed, pushed, replied) when doing repo work.
- Keep comments and console output professional; no emojis.
- Use `.jsonl` for every repository-maintained log: one JSON object per line, UTF-8, with a final newline and no blank lines. This includes ledgers, session indexes, review follow-ups, rationale, risks, and workflow events. Validate with `python3 scripts/agents/check_logs.py`; third-party runtime output is outside this rule.
- Historical repository events are recorded in [.agents/ledger.jsonl](.agents/ledger.jsonl); read it only when historical context is needed.

## Sessions

One agent system serves local shells, T3 Code threads, and GitHub runners through `scripts/agents/agentctl`.

- Register your session when work starts: `scripts/agents/agentctl sessions register --session-id '<harness>:<id>' --provider <p> --harness <h> --summary '...'`, adding `--issue`/`--pr`/`--commit` as they appear (records upsert into [.agents/sessions/index.jsonl](.agents/sessions/index.jsonl)).
- Every agent commit carries an `Agent-Session: <harness>:<id>` trailer; `scripts/agents/agentctl sessions commits <harness>:<id>` lists a session's changes. Commit with the `commit` skill.
- `make hooks` also installs a `prepare-commit-msg` hook that adds that trailer from the auto-detected session (`sessions register` needs no identity flags then; `sessions register --status completed` ends the session and archives its redacted transcript; `sessions fetch <id>` retrieves it)
- Log events with `scripts/agents/agentctl log`; `trace <commit|#N|path:line|run|session>` explains why something exists; `check-pr` is the CI gate for trailers ([details](.agents/sessions/README.md#traceability-271)).
- Before resuming from an ambiguous prior session, run `scripts/agents/agentctl context "..."`.

## Skills

- Catalog: [.agents/skills/README.md](.agents/skills/README.md), split into agent skills (model-invoked) and human skills (user-invoked; start with `/skills-guide`).
- `.agents/skills/` is the only source. `.claude/skills/`, `.gemini/skills/`, and `.gemini/commands/` are generated: edit the source, then run `scripts/agents/agentctl skills sync`; CI runs `skills check`.
- Dart/Flutter work loads `flutter-standards`. Tracker and label configuration: [.agents/tracker.md](.agents/tracker.md).

## Workflow

- Task order: (1) existing PRs, (2) open issues, (3) new issues from the `TODO.md` backlog.
- The main working folder is for meta tasks (agents, docs, research); source-code changes go in a worktree (`make worktree name=<issue>`).
- `make check` (analyze, format, test, locale-check) is green before every commit. After two consecutive failures, stop and ask; headless runs record the blocker and stop.
- Commit and push after each completed task or tight batch.

## Source of truth & sync rules

- `specs/source-of-truth/` is the canonical spec (#212). Where root docs (`README.md`, `INDEX.md`, `TODO.md`, `doc/`) conflict with it, it wins; the conflict is a sync finding.
- Shaped artifacts (`schemas/`, `registries/`, `contracts/`) are authoritative where they exist; Markdown points at them, never duplicates them (ADR 0004).
- Before doing repo work, consult `specs/source-of-truth/status.md` for domain sync state.
- Sync sessions: docs-only writes, no new concepts, contract-first authority (if the code is correct, the spec is updated). Full rules in #213; shape drift is caught in CI by `scripts/ci/check_shape_sync.dart`.
- New specs/sections/shapes require explicit owner intent, agreed before edits (ADR 0002).
- Autonomous execution boundary per ADR 0003 (`specs/source-of-truth/decisions/0003-autonomous-execution-boundary.md`).


## Integration (ADR 0006)

- Install the pre-push hook once per clone with `make hooks`; it runs `scripts/ci/local_ci.py` for the changed areas. Fix its failures before pushing; never bypass it with `--no-verify`.
- When a two-way-door PR is finalized (acceptance met, review addressed), add the `merge/auto` label; the merge gate updates and merges it. Remove the label before resuming work, then fetch: the gate may have rebased the branch.

## Dependabot PRs

For Dependabot PR updates, read the
[PR merge skill](.agents/skills/pr-merge/SKILL.md#dependabot-pr-updates).

## Secrets

- Create, rotate or set secrets (GitHub Actions secrets, `.env` keys) only through `scripts/secrets/rotate.py NAME [NAME ...]`; never call `gh secret set` or edit secret values in `.env` directly.
- Register every new secret in `scripts/secrets/registry.toml` (generator, effort, groups, public, sinks, hint) in the same change that introduces it. Never put values in the registry, code, logs, or commits.
- Any leak means rotation, without waiting for approval: rotate the leaked secret's whole group (`--group NAME` or `@NAME`), since secrets stored together leak together. Give every new secret the groups of the places it is stored.
- `effort` (low | high) describes how complex or time-consuming renewal is, never leak severity. Outside a leak, rotate only what the task needs; `--low-effort` handles routine bulk rotation. Use `--dry-run` to preview.
- Steps that need the owner (browser consent, console clicks, downloaded keys) live in [scripts/human/](scripts/human/README.md), split by domain, intent, and area. Never run them; name the script the owner should run.
- Values shipped in clients by design (bundled `.env`, Firebase client config, Facebook app ID/client token) are not leaked by being visible there; mark them `public = true`.
