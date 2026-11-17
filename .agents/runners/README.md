# Provider runners

Provider runners are adapters, not sources of truth. The command and session
ID metadata in `providers.json` was checked against the installed CLI help on
November 17, 2026; adapters must re-probe versions before execution. Each adapter must accept
the normalized workflow plan, expose a provider session ID, emit structured
events, preserve the raw provider result outside Git, and return a normalized
result that satisfies `.agents/workflows/result.schema.json`.

The command hints in `providers.json` are capability metadata. `agentctl doctor`
re-probes the installed command and version, checks the declared headless flags,
and reports whether the provider is policy-safe for the default read-only
policy. `agentctl policy compile --provider <name>` emits the same decision for
CI adapters. Planning and healing never start a provider process.

An available provider is not automatically policy-safe. A provider must have a
verified version and headless command contract, plus declared native enforcement
for every requested filesystem, network, Git, and GitHub permission. Providers
without that enforcement remain visible to routing diagnostics but fail closed
at execution time.

Required adapter lifecycle:

1. `probe` — command, version, authentication, and headless capability.
2. `start` — workflow ID, run ID, prompt/context, policy, and worktree.
3. `events` — normalized session ID, tool events, files, provider output, and
   usage counters. `agentctl` persists these as ignored `events.jsonl` run
   artifacts and never copies raw provider payloads into the ledger. Provider
   artifacts are normalized by default; raw capture requires explicit
   `--capture-raw` plus a policy allowance, and is redacted and mode-restricted.
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
