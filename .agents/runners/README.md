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

A provider may declare `permission_modes` keyed by filesystem permission. A
mode replaces the headless flags, enforced permissions, and required flags as a
whole, and is selected only when a workflow requests that filesystem
permission. Codex (`--sandbox workspace-write`) and Claude (`--permission-mode
acceptEdits --permission-prompts none`) declare `workspace-write` with Git,
network, and GitHub still read-only or none: the model edits an isolated
worktree, and the runner commits and publishes the exported patch.

CI runners can supply trusted, environment-specific manifests without changing
the repository source layer. Set `AGENT_RUNNERS_FILE`, `AGENT_POLICY_FILE`, and
`AGENT_ROUTER_FILE` to override the provider, policy, and router manifests.
Set `AGENT_SESSION_INDEX`, `AGENT_LEDGER_FILE`, `AGENT_EVENTS_DIR`,
`AGENT_KNOWLEDGE_SCHEMA`, and `AGENT_KNOWLEDGE_DB` to override the session,
ledger, event, and disposable knowledge locations (a custom index or ledger
file is single-file mode: `agentctl` appends to it instead of writing events). These overrides
are runner configuration, not workflow input, and must never be populated from
an untrusted pull request.

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
Acceptance commands also enforce `network: allowlisted` against the policy's
`allow_hosts` entries, including subdomains, before they are executed.

This boundary lets Codex, Claude, OpenCode, Gemini, Vibe, and Copilot vary in
native CLI syntax without leaking that syntax into workflow definitions.

## Model-to-work decision routing

`router.json` (validated by `router.schema.json`) maps canonical work types and
complexity tiers to policy-safe `(provider, model)` preferences. By default,
`decision_provider.enabled` is `false` and `agentctl` resolves routes locally
using `LocalWorkClassifier` and `work_routes`. When an external OpenAI-compatible
decision endpoint is enabled (`engine: "typed-decision"`), `agentctl` uses the
configured `ROUTER_BASE_URL`, `ROUTER_API_KEY`, and `ROUTER_MODEL` environment
variables (registered in `scripts/secrets/registry.toml`) with strict
`route_decision` JSON Schema output and falls back to the local selector on any
network, policy, or validation error.

Setup, diagnostics, and overrides:

- `scripts/setup/agent_router.sh --check` (or `make router-check`): non-mutating
  audit of `ROUTER_*` environment/`.env` state, active router manifest, policy
  `allow_hosts` alignment, `agentctl doctor`, and local `router decide`.
- `scripts/setup/agent_router.sh --local-only` (or `make router-setup`):
  configures/verifies deterministic local mode and checks `agentctl heal` +
  `make router-matrix` (`scripts/agents/agentctl router matrix`).
- `scripts/setup/agent_router.sh --enable-remote [--override-file <path> | --in-place] [--github] [--allow-host] [--probe]`:
  validates `ROUTER_BASE_URL`, `ROUTER_API_KEY`, and `ROUTER_MODEL`, persists them
  exclusively through `scripts/secrets/rotate.py`, writes an untracked override
  file (default `.agents/state/router.override.json` for `AGENT_ROUTER_FILE`),
  and optionally runs a live strict `route_decision` probe.
- `scripts/agents/agentctl router status` and `scripts/agents/agentctl router configure`:
  inspect readiness/credentials (without printing secret values) and update or
  emit validated router and policy allowlist configurations.
