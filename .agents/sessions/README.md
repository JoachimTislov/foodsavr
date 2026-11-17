# Agent session index

The session index correlates provider sessions with repository work. It stores
IDs and references, not transcripts or credentials. A provider adapter may add
an optional local `transcript` path; that path must remain uncommitted.

Register a session when work starts or when a provider returns an ID:

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
`agentctl query` searches the SQLite knowledge projection. It does not call
provider APIs or expose credentials. Rebuild it with
`scripts/agents/agentctl knowledge rebuild` after checkout or source changes.

## Record contract

Each JSONL line must contain `session_id`, `provider`, `harness`, `started_at`,
`status`, and `summary`. `issues`, `prs`, `sources`, and `commits` are arrays
of references. Use the provider's real session ID; do not replace it with a
human label. Link every issue, pull request, and external source relevant to
the session in the record and the corresponding ledger entry.
