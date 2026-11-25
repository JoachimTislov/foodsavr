# Agent System

Canonical specification for **using** and **managing** FoodSavr's single-control-plane agent system across local terminals, T3 Code threads, and GitHub Actions runners.

## 1. System Overview & Control Plane

One agent controller, `scripts/agents/agentctl`, governs workflows, policies, routing, skills, and traceability across all execution environments:

- **Shared instructions**: `AGENTS.md` (with `CLAUDE.md` and `GEMINI.md` symlinked to it) defines universal session, verification, secret, and integration rules.
- **Canonical skills**: `.agents/skills/` is the single source of truth; `scripts/agents/agentctl skills sync` generates `.claude/skills/`, `.gemini/skills/`, and `.gemini/commands/` projections, verified in CI by `scripts/agents/agentctl skills check`.
- **Execution boundary**: [ADR 0003](decisions/0003-autonomous-execution-boundary.md) authorizes autonomous execution of revertable actions (task branches, PRs, focused CI fixes, ledger logging) while requiring explicit owner approval for protected-branch pushes outside the merge gate, deployments, secrets, and one-way doors.

## 2. Using the Agent System

### 2.1 Session Registration & Traceability

Every coding or documentation session registers and logs its actions so work remains auditable across local and CI runs (#271):

1. **Register on start**:
   ```sh
   scripts/agents/agentctl sessions register \
     --session-id '<harness>:<id>' \
     --provider <provider> \
     --harness <harness> \
     --summary '...'
   ```
   Update with `--issue '#N'`, `--pr '#N'`, or `--commit <sha>` as artifacts are created. Each registration is a `sessions` event file under `.agents/events/`; the session index is folded from the events at read time (latest record per session wins).
2. **Commit trailer**: Every agent commit includes `Agent-Session: <harness>:<id>`. List commits for a session with `scripts/agents/agentctl sessions commits <harness>:<id>`.
3. **Ledger events**: `scripts/agents/agentctl log` writes each event as its own file, `.agents/events/<YYYY>/<MM>/<UTC timestamp>-<session slug>-<6 hex>.jsonl`, holding one UTF-8 JSON object with a `"stream": "ledger"` or `"sessions"` field (#397). No two branches share a log file, so logging never makes a PR conflict. The legacy `.agents/ledger.jsonl` and `.agents/sessions/index.jsonl` are frozen: writers never append to them (and no check fails when in-flight branches still do), readers read them before the events, ordered by timestamp. `AGENT_EVENTS_DIR` relocates the events; a custom `AGENT_LEDGER_FILE` or `AGENT_SESSION_INDEX` file is a single-file mode for tests and CI scratch copies. Label sync ignores log-only paths for `area/agents`. Validate all logs, including event files, with `python3 scripts/agents/check_logs.py`.
4. **Context lookup**: Run `scripts/agents/agentctl context "<query>"` or `scripts/agents/agentctl sessions find` before resuming prior work.

### 2.2 Declarative Workflows & Model Routing

Workflows live in `.agents/workflows/` and are validated against `.agents/workflows/schema.json`:

- `repository-health.json` — read-only repository audit (used in CI dry-run validation).
- `implement-issue.json` — isolated worktree patch generation (`filesystem: workspace-write`, `network: none`, `git: read-only`, `github: none`) under `.agents/policies/agent-implement.json`.
- `integrate-pr.json` — read-only assessment of a readied PR's author trust, door risk, check rollup, and review blockers prior to `merge/auto` opt-in.

Common operator commands:

```sh
scripts/agents/agentctl workflow validate .agents/workflows/<name>.json
scripts/agents/agentctl workflow plan .agents/workflows/<name>.json
scripts/agents/agentctl workflow run .agents/workflows/<name>.json [--execute --provider auto]
scripts/agents/agentctl router status
scripts/agents/agentctl router matrix
```

`make agent-usage` and executing workflows share a one-minute quota cache. A run filters for policy-safe providers, skips exhausted subscriptions, and prefers measured headroom. API-key providers follow measured subscriptions, and failed probes leave quota unknown. The work type and requested tier select a model on the chosen provider. Explicit provider selection still checks exhaustion.

`.agents/runners/router.json` defines model routing. The local deterministic router is the default. An enabled OpenAI-compatible decision endpoint can resolve a route when quota does not establish a preferred provider, subject to the workflow network policy. HTTP 401, 402, or 429 disables the remote router for the rest of the run and uses local routing. When no provider can execute a step, the run records a manual handoff and stops.

Run `make agent-status` for service health, one recovery action per degraded component, quotas, and recent activity. Use `scripts/agents/agentctl status -o json` for automation or `--offline` to skip remote probes.

### 2.3 Local Verification & Pre-Push Gate

- Install the pre-push hook once per clone with `make hooks`. It runs `scripts/ci/local_ci.py` for changed areas (`agents`, `docs`, `dart`, `workflows`).
- Run `make check` before committing Dart/Flutter changes. Never bypass hooks with `--no-verify`.

### 2.4 Issue-to-PR Lifecycle & PR Readiness

1. **Automated implementation**. `.github/workflows/agent-implement.yml` checks for a model login and the agent GitHub App before scheduling implementation. With both configured, it executes `implement-issue.json` in an unprivileged job, verifies the exported patch, and hands it to a separate job that commits with `Agent-Session` and opens a PR. Issue labels select a documentation or refactoring route and request deep routing for security-sensitive work.
2. **Adaptive automated review**. `.github/workflows/agent-review.yml` classifies the PR and selects the highest executable tier up to the requested tier. A model approval requires `VERDICT: APPROVE` from the verification step. The model reviews only the inline PR context (the job never checks out PR code); when that context is truncated, an approval is recorded as `commented` (`diff-truncated`), so a human merges the PR. When model execution is unavailable, the workflow records a deterministic `fast` policy review. The publisher submits a native GitHub COMMENT review on the reviewed commit. Each anchored blocker gets one diff thread with the trigger, consequence and validation criterion. Advisory and unanchored findings stay in the summary. Reply in the thread with the fix SHA and focused check result, or a counterexample and evidence. Resolve after verifying the criterion on the updated head; leave disputed findings open. The trusted review marker binds the approval to the PR and head SHA and records the requested tier, executed tier, and any capacity cap. A human review requirement still needs formal maintainer approval. The write-enabled job posts the attestation and separately records the outcome on the `agent-review-history` branch. History supports tier learning.
3. **PR readiness signal**: `.github/workflows/merge-gate.yml` triggers `dispatch` on `opened` (when `!draft`), `ready_for_review`, and `labeled` (`merge/auto`) for same-repository branches (forks are ignored), and also wakes when `"Agent review"` completes, reconciling the serialized gate on `main` and reporting ready PRs (`awaiting opt-in`, `held`, or `untrusted`).
4. **Opt-in auto-integration**: Applying `merge/auto` to a two-way-door PR hands the branch to `scripts/github/merge_gate.py` ([ADR 0006](decisions/0006-automated-integration-of-revertable-changes.md)). Before resuming manual work on an opted-in branch, remove `merge/auto` and fetch because the gate may have rebased it. `merge/auto` is also the trigger for the full `Validation` run, so human-merge PRs (`risk/security`, security paths, one-way doors) carry it too; the gate refuses to merge or update them, and the human rebases and merges.

## 3. Managing the Agent System

### 3.1 Trusted-Author Auto-Merge & Adaptive Review Policy

Auto-merging (`merge/auto` execution and Dependabot patch/minor auto-labeling) in `scripts/github/merge_gate.py` enforces **trusted-author-only** eligibility (`is_trusted_author`) and **head-bound adaptive review tier compliance** (`scripts/github/pr_review.py`):

- **Denied**: Cross-repo fork PRs (`isCrossRepository`), draft PRs, unknown authors, non-collaborator associations (`NONE`, `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, `FIRST_TIMER`, `MANNEQUIN`), unallowlisted bots, truncated review threads (`reviewThreads.pageInfo.hasNextPage`), and PRs lacking an approval for the exact `headRefOid` at the required tier or with a capacity cap attested by `github-actions[bot]`. Security-sensitive paths and `risk/security` require a human merge.
- **Allowed human authors**: Non-fork PRs opened by the repository owner (`OWNER`) or trusted repository maintainers (`MEMBER`, `COLLABORATOR`).
- **Allowed bots**: `dependabot[bot]`, `github-actions[bot]`, and an optional agent GitHub App slug configured via repository variable `AGENT_APP_SLUG` (or `--trusted-bot`).
- **Adaptive review tiers**:
  - `exempt`: trusted `dependabot[bot]` minor/patch bumps with green CI and no incident history sharing files, or both an area and a risk signature, with the PR.
  - `fast`: small, localized low-risk changes (docs, tests, narrow non-critical files) — Standards axis (`gemini-3.8-flash`, `claude-haiku-5-5`).
  - `balanced`: moderate single-area code changes — Standards + Spec axes (`gemini-4-neon`, `claude-sonnet-5-5`, `mistral-large-3`).
  - `deep`: dual-axis Standards + Spec deep review (`gpt-6.2-sol`, `claude-opus-5-5`, `gemini-4-argon`, `gemini-4-hydrogen`) for multi-area changes, `.github/workflows/`, `.agents/policies/`, `.agents/runners/`, `scripts/github/`, `scripts/agents/`, `scripts/secrets/`, `scripts/human/`, schema/ADR/data-model changes, Dependabot major bumps, or large diffs.
  - `human`: `**Door:** one-way`, untrusted authors, forks, `review/human`-style labels, truncated file lists, or PRs escalated from a prior `deep`-tier incident — requires a human maintainer `APPROVED` review at `headRefOid`. Changes under `.agents/reviews/` and `.agents/workflows/` are critical paths (`deep` at least).

### 3.2 Outcome History, Incident Investigation & Bisect Learning

`scripts/github/pr_review.py` and `.agents/reviews/history.jsonl` (strict single-line UTF-8 JSONL validated by `scripts/agents/check_logs.py`) form a closed-loop learning system when post-merge regressions occur:

- **History-driven escalation**: `classify` inspects prior `incident` records in `.agents/reviews/history.jsonl` sharing a changed file path, or both a functional area and a risk signature, with the PR. If a cheaper tier (`exempt`, `fast`, `balanced`) previously missed a regression on those paths or areas, `required_tier` automatically escalates to `deep` (or `human` if `deep` missed it) and surfaces `recommended_static_checks`.
- **Incident investigation**: `python3 scripts/github/pr_review.py investigate [--range <A..B>] [--path <file_or_dir>] [--pr <N>]` correlates git commits and merge commits with `.agents/reviews/history.jsonl`, the session index, and the ledger (legacy files plus `.agents/events/`).
- **Dual-level bisect learning**: `python3 scripts/github/pr_review.py bisect-learn --good <rev> --bad <rev> --test-cmd "<cmd>"` runs `git bisect start --first-parent` to find the culprit merge commit and, when `--bisect-branch` is active (default) on a multi-parent merge, bisects `merge-base(P1, P2)..P2` to isolate the exact feature-branch commit. It maps the culprit to its PR and original `review_tier`, records `would_deeper_tier_catch` only when the owner supplies `--deeper-review-caught yes|no` (otherwise `null`, unknown), and appends an `incident` record to `.agents/reviews/history.jsonl`. The bisect runs in a throwaway worktree, never the caller's checkout, and fails instead of reporting the starting revision when git cannot conclude. `.github/workflows/agent-incident.yml` runs it on `workflow_dispatch` and persists the incident to the history branch.

### 3.3 Runner Infrastructure Strategy (GitHub Actions Baseline)

FoodSavr uses **free GitHub Actions Linux runners** (`ubuntu-latest` / `ubuntu-24.04`) as the baseline CI and autonomous execution environment:

- Public repositories receive unlimited standard Linux minutes at `$0/month` recurring cost.
- Existing workflows natively support Flutter `3.47.6`, Dart code generation, Firebase Emulators, Playwright E2E, and `ubuntu-24.04` KVM Android emulators, plus two-job privilege isolation in `agent-implement.yml`.
- Cloud microVM sandboxes such as E2B (evaluated in #303: `$100` one-time Hobby credit with a 10 GiB disk / 1-hour runtime cap, `$150/month` Pro base + per-second usage, Linux-only) are **not** used as the primary runner; the one-time trial credit may optionally be used for isolated fork-PR verification or snapshot experiments without changing the baseline architecture.

### 3.4 Credentials, GitHub App & Human Setup

- All secrets are registered in `scripts/secrets/registry.toml` and managed exclusively via `scripts/secrets/rotate.py` (never raw `gh secret set` or manual `.env` edits).
- Owner-only interactive setup wizards live under `scripts/human/` and must be run by the human owner, never by agents:
  - `scripts/human/github/create-agent-app.sh` — provisions `AGENT_APP_ID`, `AGENT_APP_PRIVATE_KEY`, and repository variable `AGENT_APP_SLUG` (no `Workflows` permission so agent patches cannot alter CI; PRs/pushes made by the App trigger CI unlike `github.token`).
  - `scripts/human/agents/login-claude-runner.sh` / `scripts/human/agents/sync-codex-runner.sh` — configures harness logins (`CLAUDE_CODE_OAUTH_TOKEN`, `CODEX_AUTH_JSON_B64`).
  - The **Create the Release-Gate GitHub App** entry in `make human` provisions `RELEASE_GATE_APP_ID` and `RELEASE_GATE_APP_PRIVATE_KEY`. The App authenticates merge-gate integrations and release promotions (ADR 0008).

### 3.5 Remaining Integration Gaps (Spec-Ahead / Tracked)

Full hands-free PR integration tracks these open items (#303):

- **Live runner wakeups & single-writer lease (#256)**: inbound authenticated signaling so CI completion, PR readiness, or merge-gate rebases alert running T3 Code / local / Actions sessions without branch races.
- **Autonomous remediation dispatch**: dispatching a write-scoped agent repair workflow when `merge_gate.py` reports a ready PR blocked by merge conflicts, failing checks, or unresolved review threads.
- **Default-branch trailer enforcement (#277)** and **central GCS transcript archiving (#278)**.

## Nightly agent-system audit

The [Agent system audit workflow](../../.github/workflows/agent-audit.yml) runs at midnight Europe/Oslo, following local daylight saving time. You can also dispatch it manually.

### Inputs

The audit reads sessions and ledger events through `agentctl`, review attestations from `agent-review-history`, and GitHub PR, timeline, workflow run, check and commit metadata.

### Gate

The audit window starts at the previous completed audit's cutoff. The first attempt starts with the preceding 24 hours. Set the repository variables `AUDIT_MIN_SESSIONS` and `AUDIT_MIN_MERGED_PRS` to change the defaults of 10 new sessions or 5 merged PRs. Meeting either minimum completes the audit. Below both thresholds, the workflow records a deferred entry, exits successfully, and carries the same window forward. Dispatch with `force` to bypass the gate.

### Metrics

The collector measures PR flow and owner-wait labels, review outcomes and redispatches, CI outcomes and Maven 429 evidence, session activity, quota exhaustion, delivery and missing commit trailers. The first completed audit establishes the baseline. Later audits report numeric deltas and classify prior findings as resolved, improving, unchanged, or regressed.

The behind count uses known PR heads and the merge predecessor. Later force pushes can make a historical head unavailable. The collector includes CI runs created from one day before the window when they complete inside the window. It uses merge-gate evidence when readable and uses `merge/auto` removal events as a proxy otherwise. CI log availability is reported alongside matching signatures.

### Model step

The [audit workflow definition](../../.agents/workflows/agent-audit.json) routes aggregate metrics, deltas, and previous findings through the quota-aware router. The model ranks up to five findings, cites metric IDs, and proposes a small fix with an acceptance check or owner decision. Claude requires a readable weekly quota snapshot below 85%. An unavailable model leaves the deterministic report and includes the known reset time.

### Outputs

The publisher posts the report on the pinned **Agent system audit log** issue. Findings that recur in consecutive completed audits and are unchanged or worse open or update one planner issue per primary metric. The collector holds read-only contents, actions, issues and pull-request permissions. The publisher uses issue write access and writes only the audit history ref with its contents permission.

### History

The workflow appends one snapshot per run to `audits/history.jsonl` on `agent-audit-history`. Each snapshot records the time window and disposition. Completed entries also record metrics, deltas, model status, and fingerprinted findings with recommendations.
