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

`.agents/runners/router.json` routes each step's `work_type` and `tier` to policy-safe `(provider, model)` pairs, defaulting to the deterministic local classifier (`decision_provider.enabled: false`) unless an OpenAI-compatible decision endpoint is configured via `ROUTER_BASE_URL`, `ROUTER_API_KEY`, and `ROUTER_MODEL` (`make router-setup`, `make router-check`).

### 2.3 Local Verification & Pre-Push Gate

- Install the pre-push hook once per clone with `make hooks`. It runs `scripts/ci/local_ci.py` for changed areas (`agents`, `docs`, `dart`, `workflows`).
- Run `make check` before committing Dart/Flutter changes. Never bypass hooks with `--no-verify`.

### 2.4 Issue-to-PR Lifecycle & PR Readiness

1. **Automated implementation**: When the repository owner labels an issue `triage/ready-for-agent`, `.github/workflows/agent-implement.yml` executes `implement-issue.json` inside an unprivileged `implement` job (`network: none`), verifies analyze/localization/tests on the exported patch, and hands the patch to a separate `publish` job that commits with `Agent-Session:` and opens a PR.
2. **Adaptive automated review**: Opening a non-draft PR, marking a draft PR `ready_for_review`, or pushing new commits (`synchronize`) triggers `.github/workflows/agent-review.yml` on same-repository branches. The workflow classifies the PR via `scripts/github/pr_review.py classify`, pre-stages `.agents/state/pr-<N>.json` and `.agents/state/pr-<N>.md`, runs `integrate-pr.json` at the required model tier, records the outcome on the `agent-review-history` branch (`scripts/github/review_history.sh`; the merge gate and classifier fetch it, and `.agents/reviews/history.jsonl` on main is only a seed), and posts a head-bound attestation comment as `github-actions[bot]` (`<!-- agent-review: {"pr": N, "head_sha": "...", "tier": "...", "status": "approved"} -->`). The PR author never counts as its own attester, and a run only attests `approved` when an agent step ends with a `VERDICT: APPROVE` line; without a model, only the `fast` tier gets a deterministic approval and other tiers stay `commented` until a real review runs. History records are never an attestation source. The model runs in a separate read-only `review` job; the `publish` job holds write permissions, never runs a model, and re-fetches history itself. Exempt PRs record an outcome without a comment.
3. **PR readiness signal**: `.github/workflows/merge-gate.yml` triggers `dispatch` on `opened` (when `!draft`), `ready_for_review`, and `labeled` (`merge/auto`) for same-repository branches (forks are ignored), and also wakes when `"Agent review"` completes, reconciling the serialized gate on `main` and reporting ready PRs (`awaiting opt-in`, `held`, or `untrusted`).
4. **Opt-in auto-integration**: Applying `merge/auto` to a two-way-door PR hands the branch to `scripts/github/merge_gate.py` ([ADR 0006](decisions/0006-automated-integration-of-revertable-changes.md)). Before resuming manual work on an opted-in branch, remove `merge/auto` and fetch because the gate may have rebased it.

## 3. Managing the Agent System

### 3.1 Trusted-Author Auto-Merge & Adaptive Review Policy

Auto-merging (`merge/auto` execution and Dependabot patch/minor auto-labeling) in `scripts/github/merge_gate.py` enforces **trusted-author-only** eligibility (`is_trusted_author`) and **head-bound adaptive review tier compliance** (`scripts/github/pr_review.py`):

- **Denied**: Cross-repo fork PRs (`isCrossRepository`), draft PRs, unknown authors, non-collaborator associations (`NONE`, `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, `FIRST_TIMER`, `MANNEQUIN`), unallowlisted bots, truncated review threads (`reviewThreads.pageInfo.hasNextPage`), and PRs lacking a passing review attestation at `>= required_tier` for the exact `headRefOid`.
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
  - `MERGE_GATE_TOKEN` — fine-grained PAT (`Contents`, `Pull requests`, `Issues`, `Workflows` read/write) required so gate merges/rebases trigger downstream CI and release workflows.

### 3.5 Remaining Integration Gaps (Spec-Ahead / Tracked)

Full hands-free PR integration tracks these open items (#303):

- **Live runner wakeups & single-writer lease (#256)**: inbound authenticated signaling so CI completion, PR readiness, or merge-gate rebases alert running T3 Code / local / Actions sessions without branch races.
- **Autonomous remediation dispatch**: dispatching a write-scoped agent repair workflow when `merge_gate.py` reports a ready PR blocked by merge conflicts, failing checks, or unresolved review threads.
- **Default-branch trailer enforcement (#277)** and **central GCS transcript archiving (#278)**.
