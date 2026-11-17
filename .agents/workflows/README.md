# Declarative workflows

Workflow JSON files describe objectives, context, provider candidates, limits,
permissions, acceptance criteria, and outputs. They are provider-neutral input
to an adapter; they do not contain provider-specific command syntax.

Validate and plan without starting a model:

```sh
scripts/agents/agentctl workflow validate .agents/workflows/repository-health.json
scripts/agents/agentctl workflow plan .agents/workflows/repository-health.json
scripts/agents/agentctl workflow run .agents/workflows/repository-health.json
scripts/agents/agentctl doctor
scripts/agents/agentctl heal
scripts/agents/agentctl router plan .agents/workflows/repository-health.json
```

The plan includes the providers available on the current runner. An adapter
must record the provider session ID, result artifact, acceptance outcome, and
ledger references before a run can be considered complete.

Provider-specific headless metadata lives in
`.agents/runners/providers.json`; the adapter lifecycle is documented in
`.agents/runners/README.md`.

`.agents/runners/router.json` defines the router boundary. The local
policy-safe deterministic selector is always available. An optional
OpenAI-compatible decision provider (for example a Jev deployment) is
disabled by default and can only be enabled by a runner that supplies its
endpoint and credential environment variables; the local selector remains the
fallback.

`workflow run` is dry-run by default and persists a run artifact. Passing
`--execute --provider <name>` is an explicit model invocation. Execution
captures normalized output and session IDs, but remains `awaiting_acceptance`
until the declared acceptance criteria are verified. With `--provider auto`,
each step first offers policy-safe candidates to the configured decision router
and then uses the deterministic first-available fallback. The selected provider
and routing reason are persisted in the step result and event stream.
`limits.max_attempts` and `on_failure: retry` bound recovery;
`on_failure: continue` records the failure and proceeds while the overall run
remains failed. A successful execution requires a provider session ID when the
policy requires one, passing acceptance commands, and a ledger reference in the
persisted result. A step that has no policy-safe provider is recorded as
`unavailable`, which is a valid terminal result and does not masquerade as a
provider failure.

Workflow context files must resolve to regular files inside the repository.
This prevents a declarative workflow or an untrusted context reference from
reading outside the workspace.

`heal` repairs only derived local state and validation artifacts: it rebuilds
the SQLite catalog and writes `.agents/state/runs/last-maintenance.json`. It
does not edit source files, invoke a provider, or push a branch. Provider
execution remains an explicit adapter decision governed by the workflow
permissions.
