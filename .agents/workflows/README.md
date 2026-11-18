# Declarative workflows

Workflow JSON files describe objectives, context, provider candidates, limits,
permissions, acceptance criteria, and outputs. They are provider-neutral input
to an adapter; they do not contain provider-specific command syntax.

Read-only workflows use the checked-out repository by default. Any workflow
that requests workspace writes, Git branch writes, Git pushes, or GitHub writes
must declare `"worktree": {"mode": "isolated"}`. The runner creates a detached
worktree under the run artifact and executes the provider and acceptance checks
there, leaving the source checkout unchanged. Terminal runs export a
permission-restricted `changes.patch` against the recorded base revision, then
remove the isolated worktree. Healing also removes abandoned run worktrees
after confirming that the owning process is no longer active.

Validate and plan without starting a model:

```sh
scripts/agents/agentctl workflow validate .agents/workflows/repository-health.json
scripts/agents/agentctl workflow plan .agents/workflows/repository-health.json
scripts/agents/agentctl workflow run .agents/workflows/repository-health.json
scripts/agents/agentctl workflow cancel <run-id>
scripts/agents/agentctl doctor
scripts/agents/agentctl heal
scripts/agents/agentctl router plan .agents/workflows/repository-health.json
```

The plan includes the providers available on the current runner. An adapter
must record the provider session ID, result artifact, acceptance outcome, and
ledger references before a run can be considered complete.

Workflows may declare `references.issues`, `references.prs`,
`references.sources`, and `references.commits`. The runner carries these
references into the result, provider-session record, and ledger event so every
orchestration outcome remains traceable without inferring links from prose.

Provider-specific headless metadata lives in
`.agents/runners/providers.json`; the adapter lifecycle is documented in
`.agents/runners/README.md`.

`.agents/runners/router.json` defines the router boundary. The local
policy-safe deterministic selector is always available. An optional
OpenAI-compatible decision provider (for example a Jev deployment) is
disabled by default and can only be enabled by a runner that supplies its
endpoint and credential environment variables; the local selector remains the
fallback. Router requests also obey the workflow network permission and the
policy `allow_hosts` list; `network: none` never contacts the external router.

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

Declared context skills, execution limits, and outputs are included in the
normalized provider prompt so each harness receives the same orchestration
contract.

Workflow context files must resolve to regular files inside the repository.
This prevents a declarative workflow or an untrusted context reference from
reading outside the workspace.

Acceptance commands are executed without a shell. Validation rejects shell
composition, redirection, destructive filesystem commands, mutating Git
operations, inline code execution, and network or GitHub commands that exceed
the workflow permissions. Captured acceptance output is redacted before it is
stored in a result artifact.

`heal` repairs only derived local state and validation artifacts: it validates
the policy, runner, router, label, and workflow manifests; normalizes legacy
planned result artifacts; deduplicates legacy session snapshots; recovers
abandoned `running` artifacts when their active process is gone; rebuilds the
SQLite catalog; and writes
`.agents/state/runs/last-heal.json`. It leaves live runs untouched. It does not
edit source files, invoke a provider, or push a branch. Provider execution
remains an explicit adapter decision governed by workflow permissions.

Agent-system CI also runs the repository-health workflow in provider-free dry
run mode with a runner-local ledger and SQLite projection. This exercises run
artifact, event, reference, and ledger persistence without invoking a harness
or modifying tracked repository state.

Use `workflow cancel <run-id>` to transition a planned or running artifact to
`cancelled`. The controller records a cancellation event and ledger reference,
removes the active marker, and signals the owning runner when its process is
still present. Terminal runs are left unchanged.
