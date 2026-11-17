# GitHub automation

`.agents/github/labels.json` is the source of truth for repository labels and
classification rules. The `github-labels.yml` workflow checks out the trusted
default branch and reacts to issue, pull-request, and selected workflow-run
events.

The synchronizer manages only namespaced labels (`type/`, `area/`, `status/`,
`risk/`, and `automation/`). It removes stale labels in those namespaces but
preserves all other labels, including human triage labels. It is safe to preview
the result without mutation:

```sh
python3 scripts/github/sync_labels.py --repo OWNER/REPO --number 123
```

The workflow applies the same result with `--apply`, creates missing managed
labels idempotently, and uses the commit SHA for workflow-run events so CI
state can update the corresponding pull request.
