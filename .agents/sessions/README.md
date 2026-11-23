# Agent session index

The session index correlates provider sessions with repository work. It stores
IDs and references, not transcripts or credentials. Transcripts live in the
private archive bucket (see [Transcript archive](#transcript-archive-278)); an
index record may carry only the resulting `gs://` URI in `transcript`. Local
transcript paths are never committed (`check_logs.py` rejects them).

## Traceability (#271)

Every commit, PR, ledger event, and CI run resolves to a session or to an
explicitly declared human. Session IDs are `<harness>:<native-id>` (for example
`t3-code:<thread id>`); the harness is detected from the environment
(`AGENT_SESSION_ID` override, `T3CODE_THREAD_ID`, `CLAUDE_CODE_SESSION_ID`, `CODEX_THREAD_ID`,
GitHub Actions; lower-priority detections are kept as `related`). Add a harness with one row in
`SESSION_ENV` in [traceability.py](../../scripts/agents/traceability.py).
Legacy bare IDs still resolve by their native ID; history is never rewritten.

```sh
make hooks                                     # once per clone: pre-push CI mirror + Agent-Session trailer on every agent commit
scripts/agents/agentctl sessions register --summary '...' --issue '#271'   # identity auto-detected; first command of a session
scripts/agents/agentctl sessions current       # which session am I, and how do I reopen it
scripts/agents/agentctl log 'what changed' --commit HEAD --pr '#300'       # ledger event with session_id
scripts/agents/agentctl sessions register --status completed               # last command: stamps ended_at
scripts/agents/agentctl sessions commits <id>  # commits carrying the trailer (trace reuses this lookup)
scripts/agents/agentctl trace '#300'           # why does this exist? (also SHA, path:line, issue, run id, session)
```

- Refs are canonical as `#N` (PRs, issues) and full commit SHAs; URLs and short
  SHAs are accepted on input.
- Rebase merges drop the PR body, so ownership lives in commits: the
  `Traceability` workflow fails a PR when a non-bot commit lacks an
  `Agent-Session:` trailer. The PR body may only say `Agent-Session: none
  (human)`, which exempts trailer-less (human) commits; session IDs in the body
  are informational. Trailers naming sessions missing from the index warn.
- Rebase rewrites SHAs, so logs recorded before a merge name commits that are
  gone from `main`. `trace` maps a commit to recorded SHAs by `patch-id` (old
  object still local) or author date + email + subject, and reports the match
  ("via rebase-equivalent a0d0f8b (patch-id)"). Fingerprints are cached in
  `.agents/state/equivalence.json`. `trace '#N'` links a PR to commits through
  `(#N)` subjects (squash), the PR's sessions' trailers (inferred), or `--online`
  (`gh`, 10 s timeout per call: exact rebased range, and commit to PR).
- `knowledge rebuild` writes commits and trace edges (commit, session, PR, issue,
  run, equivalence) into the SQLite projection; `trace` uses it while it matches
  the working tree (`engine: projection`) and otherwise computes from git.
  `query` and `context` show the sessions behind matching commits.
- Each traced session lists how to reopen it (`claude --resume <id>`,
  `codex resume <id>`, a GitHub run URL) and whether its transcript is local
  (path only; contents are never read). Table: `LOCATORS` in `traceability.py`.
- Logs are per-event files (#397): every ledger event and session registration is its own
  `.agents/events/<YYYY>/<MM>/<UTC timestamp>-<session slug>-<6 hex>.jsonl` holding one JSON
  object (its record plus `"stream": "ledger"` or `"sessions"`), so branches never edit the same
  file and never conflict. Session writers add an event only when the record changed
  (`--status completed` stamps `ended_at`); readers fold the session events (arrays union, latest
  scalar wins, attempts kept) and order ledger events by timestamp. Never hand-edit or delete events.
- `.agents/ledger.jsonl` and `.agents/sessions/index.jsonl` are frozen: readers keep reading them
  before the events, writers never append to them, and `agentctl maintain` never rewrites them.
  Their `merge=union` attribute stays for in-flight branches created before the change; no check
  fails when they change. `AGENT_EVENTS_DIR` selects another events directory; a custom
  `AGENT_SESSION_INDEX` or `AGENT_LEDGER_FILE` file (tests, CI scratch copies) is single-file mode and is appended to directly.
- `trace --infer` (opt-in) also guesses sessions whose `started_at`..`ended_at` window brackets the commit and whose refs overlap; results are labelled `inferred`, are never evidence for doctor coverage, and are never stored as projection edges.
- Ledger events on or after `traceability.CUTOFF` need a registered
  `session_id` (`check_logs.py`); older lines are grandfathered.
- CI runs upload `provenance-<job>` artifacts and job summaries (run, commit,
  PR, sessions). `agentctl doctor` lists traceability gaps.

## Transcript archive (#278)

Config: [archive.json](archive.json) (project, bucket, location, prefix; env
`AGENT_SESSION_BUCKET` overrides the bucket). No secret is involved: access is
your own `gcloud auth login`.

```sh
scripts/agents/agentctl sessions archive [--session ID] [--dry-run] [--json]  # also runs on `sessions register --status completed` (--no-archive skips)
scripts/agents/agentctl sessions fetch <session-id> [--out DIR]               # ~/.cache/foodsavr/agent-sessions/<harness>/<native>/<sha>/
scripts/agents/agentctl sessions provision-archive [--apply]                          # OWNER ONLY (ADR 0003): prints, or runs, the gcloud commands
```

- Bundle: deterministic `tar.gz` of the main transcript, Claude Code subagent
  files and `manifest.json` (files with sha256/bytes, redaction counts). Object:
  `sessions/<harness>/<native>/<sha256>.tar.gz`, uploaded `--no-clobber`, so
  objects are immutable. The index records `transcript`, `transcript_sha256`,
  `archived_at`; `trace` shows the URI and the `sessions fetch` command.
- Redaction is per decoded JSON string, deterministic and fail-closed: exact
  values of non-public secrets from `scripts/secrets/registry.toml` (environment,
  repo `.env`, main checkout `.env`), known token shapes, PEM keys, `Bearer`,
  `*TOKEN|SECRET|PASSWORD|API_KEY...=value` assignments and email addresses
  (`noreply@`, `users.noreply.github.com`, `git@` kept). The output is re-scanned;
  a surviving hit or an invalid JSON line aborts with rule names and line numbers
  only. Redaction is best-effort pattern matching: review `--dry-run` counts for
  sensitive work, and keep the bucket private.
- `fetch` verifies the sha256 in the object name, rejects absolute/`..`/link
  members, and checks the manifest before extracting.
- Archive failures warn and never block `sessions register --status completed`. `agentctl doctor` reports
  config, gcloud availability/auth, and sessions without an archive.

Register a session manually (providers without detection) with:

```sh
scripts/agents/agentctl sessions register \
  --session-id 'vibe:session-id' \
  --provider mistral \
  --harness vibe \
  --issue '#212' \
  --pr '#235' \
  --source 'https://docs.mistral.ai/vibe/work/skills' \
  --summary 'Audit agent setup and session access'
```

Query sessions and repository context from any shell, agent, or CI runner:

```sh
scripts/agents/agentctl sessions list
scripts/agents/agentctl query 'FoodSavr TODO'
scripts/agents/agentctl context 'current app status and open work'
```

The JSON output is intended for harness adapters and orchestration scripts.
The session index is folded at read time from the legacy index and the session
events: repeated provider session IDs are upserted with an `attempts` history so
the relational projection retains a single primary-key row. `agentctl query` searches the SQLite knowledge projection. It does not call
provider APIs or expose credentials. Rebuild it with
`scripts/agents/agentctl knowledge rebuild` after checkout or source changes.

## Record contract

Each session record (a legacy index line or a `sessions` event) must contain `session_id`, `provider`, `harness`, `started_at`,
`status`, and `summary`; a `ledger` event needs `timestamp`, `session_id`, and `event` (or `type`). `issues`, `prs`, `sources`, and `commits` are arrays
of references. Use the provider's real session ID; do not replace it with a
human label. Link every issue, pull request, and external source relevant to
the session in the record and the corresponding ledger entry.

## Repository event logs

Record repository events with `agentctl log`, which writes a ledger event under
[.agents/events/](../events/) as a JSON object with `timestamp` (UTC) and `event`; it
includes session IDs and issue, PR, source, and commit references when available. Record changes, commits, pushes, replies,
and unresolved blockers. Keep transcripts and credentials outside the repository.
Workflow completions use structured run, workflow, provider, status, artifact,
and reference fields. The ledger is append-only (history before #397 lives in the frozen
[ledger](../ledger.jsonl)); the session index remains an upserted snapshot with attempt history. Rebuild the SQLite projection after
source changes with `scripts/agents/agentctl knowledge rebuild`.

The format rule in [AGENTS.md](../../AGENTS.md) covers all repository logs.
