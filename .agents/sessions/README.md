# Agent session index

The session index correlates provider sessions with repository work. It stores
IDs and references, not transcripts or credentials. A provider adapter may add
an optional local `transcript` path; that path must remain uncommitted.

Register a session when work starts or when a provider returns an ID:

```sh
python3 scripts/agents/session_query.py register \
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
python3 scripts/agents/session_query.py list
python3 scripts/agents/session_query.py show 'vibe:session-id'
python3 scripts/agents/session_query.py search 'FoodSavr TODO'
python3 scripts/agents/session_query.py validate
```

The JSON output is intended for harness adapters and orchestration scripts.
The `search` command searches registered metadata, `.agents/ledger.md`,
`TODO.md`, `README.md`, and any registered local transcripts. It does not call
provider APIs or expose credentials.

## Record contract

Each JSONL line must contain `session_id`, `provider`, `harness`, `started_at`,
`status`, and `summary`. `issues`, `prs`, `sources`, and `commits` are arrays
of references. Use the provider's real session ID; do not replace it with a
human label. Link every issue, pull request, and external source relevant to
the session in the record and the corresponding ledger entry.
