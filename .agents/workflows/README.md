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
OpenAI-compatible decision provider is disabled by default and can only be
enabled by a runner that supplies its endpoint and credential environment
variables (`ROUTER_BASE_URL`, `ROUTER_API_KEY`, `ROUTER_MODEL`); the local
selector remains the fallback. Router requests also obey the workflow network
permission and the policy `allow_hosts` list; `network: none` never contacts
the external router.

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

## Implementing issues

`implement-issue.json` turns one `triage/ready-for-agent` issue into a patch.
It requests `workspace-write` only, so it runs under
`.agents/policies/agent-implement.json` (the default read-only policy rejects
it). The same command works locally, in T3 Code, and on a runner:

```sh
jq --arg f .agents/state/issue-42.md '.context.files += [$f] | .references.issues = ["#42"]' \
  .agents/workflows/implement-issue.json > .agents/state/workflows/implement-issue.json
AGENT_POLICY_FILE=.agents/policies/agent-implement.json \
  scripts/agents/agentctl workflow run .agents/state/workflows/implement-issue.json --execute --provider auto
```

The run ends `awaiting_acceptance` with `changes.patch` (new files included);
verification belongs to whoever applies the patch.
`.github/workflows/agent-implement.yml` does this when the owner labels an
issue: an unprivileged job runs the provider and verifies the patch (analyze,
localization, tests), and a separate job applies it, commits with the
`Agent-Session` trailer, opens a draft PR, and comments on the issue. It uses
harness logins, never API keys: `CLAUDE_CODE_OAUTH_TOKEN` (from `claude
setup-token`, a Claude subscription) and, optionally, `CODEX_AUTH_JSON_B64`
(a mirror of `~/.codex/auth.json`). Store them with `scripts/secrets/rotate.py
CLAUDE_CODE_OAUTH_TOKEN`. The Codex login shares its refresh token with this
machine, so re-sync it if either side stops authenticating.

Publishing uses the agent GitHub App when `AGENT_APP_ID` and
`AGENT_APP_PRIVATE_KEY` are set (`scripts/human/github/create-agent-app.sh` walks
through creating and installing it): commits, PRs, and comments come from
`<app>[bot]` with a one-hour installation token, and its pushes trigger CI.
The App has no Workflows permission, so agent patches cannot change CI.
Without it, the job falls back to the Actions token, whose PRs start no
workflows.

## Integrating readied PRs

`integrate-pr.json` is a read-only triage and verification workflow for
assessing whether a readied PR meets ADR 0006 criteria (non-draft, non-fork,
trusted author, two-way door, required adaptive review tier, green check rollup,
no unresolved review threads) before applying `merge/auto`. Because the workflow
runs with `"network": "none"` and `"github": "none"`, callers pre-stage the
target PR snapshot into `.agents/state/pr-<N>.json` and `.agents/state/pr-<N>.md`
and bind `references.prs` and the adaptive review tier before invoking
`agentctl workflow run` (matching `implement-issue.json`'s pre-staged issue
pattern):

```sh
python3 scripts/github/pr_review.py classify \
  --pr 42 \
  --pr-json .agents/state/pr-42-raw.json \
  --diff-file .agents/state/pr-42.diff \
  --stage-dir .agents/state \
  --stage-workflow .agents/state/workflows/integrate-pr-42.json
scripts/agents/agentctl workflow run .agents/state/workflows/integrate-pr-42.json --execute --provider auto
```

Or manually with `jq`:

```sh
jq --arg json .agents/state/pr-42.json --arg md .agents/state/pr-42.md \
  '.context.files += [$json, $md] | .references.prs = ["#42"]' \
  .agents/workflows/integrate-pr.json > .agents/state/workflows/integrate-pr-42.json
scripts/agents/agentctl workflow run .agents/state/workflows/integrate-pr-42.json --execute --provider auto
```

`.github/workflows/agent-review.yml` runs this classification and review pipeline
automatically on non-draft, non-fork pull requests and posts a head-bound
review attestation (`<!-- agent-review: ... -->`), while
`.github/workflows/merge-gate.yml` and `scripts/github/merge_gate.py` enforce
that the attested review tier at `headRefOid` meets or exceeds the PR's
`required_tier` (including any history-driven escalation from
`.agents/reviews/history.jsonl`).
