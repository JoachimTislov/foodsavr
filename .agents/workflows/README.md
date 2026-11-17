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
```

The plan includes the providers available on the current runner. An adapter
must record the provider session ID, result artifact, acceptance outcome, and
ledger references before a run can be considered complete.

Provider-specific headless metadata lives in
`.agents/runners/providers.json`; the adapter lifecycle is documented in
`.agents/runners/README.md`.

`workflow run` is dry-run by default and persists a run artifact. Passing
`--execute --provider <name>` is an explicit model invocation. Execution
captures raw output and session IDs, but remains `awaiting_acceptance` until
the declared acceptance criteria are verified.

`heal` repairs only derived local state and validation artifacts: it rebuilds
the SQLite catalog and writes `.agents/state/runs/last-maintenance.json`. It
does not edit source files, invoke a provider, or push a branch. Provider
execution remains an explicit adapter decision governed by the workflow
permissions.
