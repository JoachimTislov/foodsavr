# Agent session index

The session index correlates provider sessions with repository work. It stores
IDs and references, not transcripts or credentials. A provider adapter may add
an optional local `transcript` path; that path must remain uncommitted.

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
- Logs are append-only and `merge=union` in `.gitattributes`. Session writers
  append a line only when the record changed (`--status completed` stamps `ended_at`); readers fold duplicate
  `session_id` lines (arrays union, latest scalar wins, attempts kept);
  only `agentctl maintain` compacts (`heal` never rewrites tracked logs, so CI stays clean). Do not hand-edit old lines.
- `trace --infer` (opt-in) also guesses sessions whose `started_at`..`ended_at` window brackets the commit and whose refs overlap; results are labelled `inferred`, are never evidence for doctor coverage, and are never stored as projection edges.
- Ledger events on or after `traceability.CUTOFF` need a registered
  `session_id` (`check_logs.py`); older lines are grandfathered.
- CI runs upload `provenance-<job>` artifacts and job summaries (run, commit,
  PR, sessions). `agentctl doctor` lists traceability gaps.

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
The JSONL index is a compact session snapshot: repeated provider session IDs
are upserted with an `attempts` history so the relational projection retains a
single primary-key row. `agentctl query` searches the SQLite knowledge projection. It does not call
provider APIs or expose credentials. Rebuild it with
`scripts/agents/agentctl knowledge rebuild` after checkout or source changes.

## Record contract

Each JSONL line must contain `session_id`, `provider`, `harness`, `started_at`,
`status`, and `summary`. `issues`, `prs`, `sources`, and `commits` are arrays
of references. Use the provider's real session ID; do not replace it with a
human label. Link every issue, pull request, and external source relevant to
the session in the record and the corresponding ledger entry.

## Repository event logs

Append repository events to [the ledger](../ledger.jsonl) as JSON objects with
`timestamp` (UTC) and `event`; include session IDs and issue, PR, source, and
commit references when available. Record changes, commits, pushes, replies,
and unresolved blockers. Keep transcripts and credentials outside the repository.
Workflow completions use structured run, workflow, provider, status, artifact,
and reference fields. The ledger is append-only; the session index remains an
upserted snapshot with attempt history. Rebuild the SQLite projection after
source changes with `scripts/agents/agentctl knowledge rebuild`.

The format rule in [AGENTS.md](../../AGENTS.md) covers all repository logs.
