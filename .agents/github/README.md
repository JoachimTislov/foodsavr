# GitHub automation

`.agents/github/labels.json` is the source of truth for repository labels and
classification rules. The `github-labels.yml` workflow checks out the trusted
default branch and reacts to issue, pull-request, and selected workflow-run
events.

The synchronizer manages only purpose-driven namespaced labels (`type/`,
`area/`, `status/ci-*`, and `risk/`). GitHub remains the source of truth for
open/closed, draft/ready, and review state, so those states are deliberately
not duplicated as labels. It removes stale managed and explicitly retired
legacy labels but preserves other human triage labels. It is safe to preview
the result without mutation:

```sh
python3 scripts/github/sync_labels.py --repo OWNER/REPO --number 123
```

The `merge/auto` label is outside the managed prefixes: authors set it, and
`merge-gate.yml` integrates labeled PRs (ADR 0006). Preview its next step with
`python3 scripts/github/merge_gate.py --repo OWNER/REPO`.

The workflow applies the same result with `--apply`, creates missing managed
labels idempotently, and uses the commit SHA for workflow-run events so CI
state can update the corresponding pull request.
