# CI & Workflows

Absorbed from `.github/workflows/` @ 103a70f:

- `ci-checks.yml` — analyze, localization check, unit tests, coverage.
- `build-web.yml` / `build-android.yml` — platform builds; Android emulator jobs pinned to `ubuntu-24.04` ahead of the Ubuntu 26 migration (#200/#189).
- `docs-pages.yml` — strict MkDocs build and local navigation/asset validation on documentation PRs; trusted `main` changes publish the vision, canonical spec, and project docs to GitHub Pages. This is the sole Pages deployment owner; `build-web.yml` retains Flutter build artifacts without deploying them.
- `validation.yml` — validation gates; `release-gated.yml` — release workflow (#145).
- For matching non-pull-request changes, Firestore rules are validated when the `FIRESTORE_RULES_B64` secret is configured; an unset secret emits a warning and skips validation. Rules themselves remain deliberately untracked (#165/#185).
- Duplicate-run avoidance: `scripts/ci/already_tested.sh` skips push-to-`main` runs of `ci-checks.yml` and `validation.yml` only when the pushed commit tree equals a merged PR head tree with a green run of the same workflow; builds still run on push (release artifacts). Workflows use per-PR concurrency with cancel-in-progress; `ci-checks.yml` path-filters PRs inside its gate job so its checks always report.
- `merge-gate.yml` — integrates PRs labeled `merge/auto` one at a time: merges when up to date with every head check green, otherwise rebases the oldest `BEHIND` PR (`@dependabot rebase` for Dependabot); runs as `MERGE_GATE_TOKEN` (ADR 0006).
- `scripts/ci/local_ci.py` — local mirror of CI for changed areas, run by the `.githooks/pre-push` hook (`make hooks`); `agent-system.yml` and `docs-pages.yml` run its `agents` and `docs` groups, and its `dart` group is kept equal to `ci-checks.yml` at CI's pinned Flutter version.
- Default-branch ruleset requires PRs (rebase only), linear history, up-to-date branches and checks `Decide whether to run CI`, `Check & Test`, `Detect changed areas`, `Web smoke test`, `Android smoke test`.
