# Provider runners

Provider runners are adapters, not sources of truth. The command and session
ID metadata in `providers.json` was checked against the installed CLI help on
November 17, 2026; adapters must re-probe versions before execution. Each adapter must accept
the normalized workflow plan, expose a provider session ID, emit structured
events, preserve the raw provider result outside Git, and return a normalized
result that satisfies `.agents/workflows/result.schema.json`.

The command hints in `providers.json` are capability metadata only. They are
not executed by `agentctl plan` or `agentctl heal`. A future runner may use
them after resolving provider-specific permissions, authentication, and output
format from the installed CLI version.

Required adapter lifecycle:

1. `probe` — command, version, authentication, and headless capability.
2. `start` — workflow ID, run ID, prompt/context, policy, and worktree.
3. `events` — normalized session ID, tool events, files, provider output, and
   usage counters. `agentctl` persists these as ignored `events.jsonl` run
   artifacts and never copies raw provider payloads into the ledger.
4. `result` — acceptance checks, artifacts, references, and final status.
5. `cancel` — bounded cancellation and cleanup.

Usage is best-effort and provider-neutral: recognized token/cost fields are
aggregated into the result's `usage` object and session record. Missing usage
does not fail a run; missing required session IDs still does. Provider-specific
fields are declared in `providers.json` so adapters can add mappings without
changing workflow files.

Policy compilation passes the normalized policy to the adapter. An adapter
must translate only capabilities it can enforce and fail closed for the rest;
it must never silently broaden filesystem, network, Git, or GitHub permissions.

This boundary lets Codex, Claude, OpenCode, Gemini, Vibe, and Copilot vary in
native CLI syntax without leaking that syntax into workflow definitions.
