# CI pipeline audit

Measure recent GitHub Actions runs to classify every failure, cancellation, and wasted runner minute before proposing workflow or queue changes.

## 1. Pull run history for the integration window

Fetch recent workflow runs (paginate across the full integration window, e.g. last 24-48h or since a session start timestamp):

```sh
python3 - "$CUTOFF" <<'PY'
import json, subprocess
from collections import Counter, defaultdict
from datetime import datetime

import sys
# usage: python3 - <cutoff ISO-8601 UTC, e.g. 2026-11-23T17:00:00Z>
CUTOFF = sys.argv[1]  # window start
REPO = json.loads(subprocess.check_output(
    ["gh", "repo", "view", "--json", "nameWithOwner"], text=True))["nameWithOwner"]

runs = []
page = 0
while True:  # paginate until the cutoff; never silently cap coverage
    page += 1
    batch = json.loads(subprocess.check_output(
        ["gh", "api", f"repos/{REPO}/actions/runs?per_page=100&page={page}"], text=True
    )).get("workflow_runs", [])
    runs.extend(batch)
    if not batch or batch[-1]["created_at"] < CUTOFF:
        break

recent = [r for r in runs if r["created_at"] >= CUTOFF]
by_wf = defaultdict(Counter)
dur = defaultdict(lambda: defaultdict(float))
for r in recent:
    c = r["conclusion"] or r["status"]
    by_wf[r["name"]][c] += 1
    # Runner minutes are the sum of job durations, not workflow wall time.
    jobs = json.loads(subprocess.check_output(
        ["gh", "api", f"repos/{REPO}/actions/runs/{r['id']}/jobs?per_page=100"], text=True
    )).get("jobs", [])
    for job in jobs:
        if job.get("started_at") and job.get("completed_at"):
            t0 = datetime.fromisoformat(job["started_at"].replace("Z", "+00:00"))
            t1 = datetime.fromisoformat(job["completed_at"].replace("Z", "+00:00"))
            dur[r["name"]][c] += max(0.0, (t1 - t0).total_seconds())

for wf, counts in sorted(by_wf.items(), key=lambda x: -sum(x[1].values())):
    d = dur[wf]
    print(f"{wf:50s} tot={sum(counts.values()):3d} ok={counts['success']:3d} "
          f"fail={counts['failure']:3d} canc={counts['cancelled']:2d} "
          f"min(ok/fail/canc)={d['success']/60:5.1f}/{d['failure']/60:5.1f}/{d['cancelled']/60:4.1f}")
PY
```

Set `CUTOFF` (for example `CUTOFF=2026-11-23T17:00:00Z`) before running.

## 2. Classify root causes

For every non-green run (or a stratified sample when one workflow dominates):

1. Inspect failed jobs and steps via `gh api repos/<owner>/<repo>/actions/runs/<id>/jobs` and `gh run view <id> --log-failed`.
2. Bucket every failure into one root cause:
   - **Shared secret / infra outage** (e.g. App PEM `Invalid keyData`, corrupt Firebase client options, missing WIF vars)
   - **Local CI blind spot** (passed locally, failed in CI due to missing test group or runner env var like `GITHUB_REPOSITORY`)
   - **Upstream / external drift** (third-party CLI flag change, rate limit, live probe failure)
   - **Real code/test regression** (actual bug caught by CI)
   - **Process / race** (stale base, open-then-label cancellation, mid-run rebase cancellation)
3. Inspect active rulesets (`gh api repos/<owner>/<repo>/rulesets`) to spot duplicate rulesets, strict up-to-date cascades, or checks that run on paths they cannot affect.

## 3. Report actionable metrics

Summarize findings with:

- **Totals**: runs, pass/fail/cancel counts and percentages, runner minutes (sum of job durations) total vs wasted, and runs per merged PR.
- **Top failure clusters**: ranked by run count and runner minutes, each with concrete run IDs and root cause.
- **Redundancy hotspots**: workflows firing on out-of-scope paths (e.g. `.agents/events/**`, `scripts/ci/*.py`) or excessive `workflow_run` fan-out.
- **Ordered fixes**: (1) immediate blocker/secret fixes, (2) local preflight additions, (3) workflow trigger & path-filter trims, (4) tiering changes that keep path-gated smoke/E2E on `develop` PRs.

Done when every failure in the window is assigned a verified root cause and every recommendation cites the exact workflow, file, or ruleset to change.
