"""Collect, compare, and publish the nightly agent-system audit."""

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from hashlib import sha256
from html import escape
import json
import math
import os
from pathlib import Path
import re
import shlex
import shutil
import statistics
import subprocess
import tempfile
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from urllib.parse import urlencode

import agentctl

ROOT = Path(__file__).resolve().parents[2]
HISTORY = Path("audits/history.jsonl")
BRANCH = "agent-audit-history"
WORKFLOW = Path(".agents/workflows/agent-audit.json")
BOT = "github-actions[bot]"
OWNER_WAIT_LABELS = {"risk/security", "triage/needs-info", "triage/ready-for-human"}
REVIEW_OUTCOMES = ("approved", "blocked", "skipped", "capped", "hollow")
FAILURES = {"failure", "timed_out", "startup_failure", "action_required"}
# Validation-suite jobs of pull-request.yml (#496): a run that executed none of the
# substantive ones (weekly agent check, `operation=checks` dispatch, reuse-only run)
# never validated, so its duration must not dilute ci.validation.median-hours.
VALIDATION_SUBSTANTIVE_JOBS = frozenset({"Web smoke test", "Android smoke test", "Firestore security rules"})
VALIDATION_SUITE_JOBS = VALIDATION_SUBSTANTIVE_JOBS | {"Detect changed areas", "Validation status (result)"}


def fingerprint(value):
    return sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()[:20]


def key(value):
    # Metric IDs remain stable and cannot contain markup or arbitrary source text.
    if re.fullmatch(r"[a-z0-9-]+", value):
        return value
    return fingerprint(value)


def time(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00")) if value else None


def in_window(value, start, end):
    moment = time(value)
    return moment is not None and start < moment <= end


def rate(count, total):
    return round(count / total, 4) if total else None


def hours(start, end):
    return round((time(end) - time(start)).total_seconds() / 3600, 4)


def percentile(values, fraction):
    return sorted(values)[math.ceil(len(values) * fraction) - 1] if values else None


def threshold_met(sessions, merged, minimum_sessions=10, minimum_merged=5, force=False):
    return force or sessions >= minimum_sessions or merged >= minimum_merged


def rows(path):
    return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, sort_keys=True, allow_nan=False) + "\n")


def previous_audit(history):
    return next((row for row in reversed(history) if row["status"] == "completed"), None)


def owner_wait(events, start, end):
    active = set()
    last = start
    total = timedelta()
    for event in sorted(events, key=lambda row: row.get("created_at") or ""):
        label = (event.get("label") or {}).get("name")
        if label not in OWNER_WAIT_LABELS or event["event"] not in {"labeled", "unlabeled"}:
            continue
        moment = time(event["created_at"])
        if moment > end:
            break
        if active:
            total += max(moment - last, timedelta())
        if event["event"] == "labeled":
            active.add(label)
        else:
            active.discard(label)
        last = max(start, moment)
    return round((total + (end - last if active else timedelta())).total_seconds() / 3600, 4)


def pr_metrics(data, start, end):
    merged = data["merged"]
    open_prs = data["open"]
    durations = [hours(pr["created_at"], pr["merged_at"]) for pr in merged]
    metrics = {
        "pr.merged": len(merged), "pr.open": len(open_prs),
        "pr.merge-hours-p50": percentile(durations, .5),
        "pr.merge-hours-p90": percentile(durations, .9),
        "pr.human-merge-share": rate(
            sum(not pr["merge_bot"] for pr in merged if pr["merge_bot"] is not None),
            sum(pr["merge_bot"] is not None for pr in merged),
        ),
    }
    for pr in merged + open_prs:
        number = pr["number"]
        events = pr["timeline"]
        window = [event for event in events
                  if in_window(event.get("submitted_at") or event.get("created_at"), start, end)]
        reviews = {event.get("commit_id") for event in window
                   if event["event"] == "reviewed" and event.get("commit_id")}
        reviews.update(row["head_sha"] for row in data["reviews"]
                       if row.get("pr") == number and row.get("head_sha") and not row.get("carried_from_sha"))
        prefix = f"pr.{number}"
        metrics[f"{prefix}.review-rounds"] = len(reviews)
        metrics[f"{prefix}.force-pushes"] = sum(row["event"] == "head_ref_force_pushed" for row in window)
        metrics[f"{prefix}.rebases"] = pr["rebases"]
        metrics[f"{prefix}.owner-wait-hours"] = owner_wait(
            events, start, min(end, time(pr.get("merged_at")) or end),
        )
    for field in ("review-rounds", "force-pushes", "rebases", "owner-wait-hours"):
        metrics[f"pr.{field}"] = sum(metrics[f"pr.{pr['number']}.{field}"] for pr in merged + open_prs)
    behind_counts = [pr["sent_behind"] for pr in merged if pr["sent_behind"] is not None]
    for pr in merged:
        metrics[f"process.merge-{pr['number']}.sent-behind"] = pr["sent_behind"]
    metrics["process.sent-behind-per-merge"] = rate(sum(behind_counts), len(behind_counts))
    metrics["process.merge-auto-removed"] = data["held"]
    return metrics


def is_review_run(run):
    """Adaptive review runs: the Agent Ops review operation, or the retired Agent review workflow."""
    return run["name"] == "Agent review" or (
        run["name"] == "Agent Ops" and str(run.get("display_title") or "").startswith("Agent Ops: review"))


def review_metrics(reviews, runs):
    per_provider = defaultdict(list)
    for review in reviews:
        per_provider[key(str(review.get("provider") or "none"))].append(review)
    metrics = {}
    for provider, group in per_provider.items():
        counts = Counter(row.get("status") for row in group)
        counts["capped"] = sum(bool(row.get("cap_reason")) for row in group)
        counts["hollow"] = sum(bool(row.get("diff_truncated") or row.get("hollow") or
                                    row.get("reason") in {"diff-truncated", "empty-evidence"} or
                                    (row.get("status") in {"approved", "blocked"} and
                                     (not row.get("summary") or re.fullmatch(
                                         r"Adaptive [a-z-]+ review \([a-z-]+\) for PR #\d+ at [0-9a-f]+\.",
                                         row["summary"])))) for row in group)
        for outcome in REVIEW_OUTCOMES:
            metrics[f"review.{provider}.{outcome}-share"] = rate(counts[outcome], len(group))
    metrics["review.redispatched"] = sum(run["event"] == "workflow_dispatch" for run in runs if is_review_run(run))
    return metrics


def ci_metrics(runs):
    groups = defaultdict(list)
    for run in runs:
        groups[run["name"]].append(run)
    metrics = {}
    for name, group in groups.items():
        prefix = f"ci.{key(name.lower().replace(' ', '-'))}"
        metrics[f"{prefix}.failure-rate"] = rate(sum(r["conclusion"] in FAILURES for r in group), len(group))
        metrics[f"{prefix}.cancel-rate"] = rate(sum(r["conclusion"] == "cancelled" for r in group), len(group))
        metrics[f"{prefix}.rerun-rate"] = rate(sum(r["run_attempt"] > 1 for r in group), len(group))
    metrics["ci.maven-429"] = sum(run.get("maven_429", False) for run in runs)
    metrics["ci.logs-unavailable"] = sum(run.get("log_unavailable", False) for run in runs)
    # PR verification, including Validation, runs in `Pull Request` since #496. Only
    # runs that executed a substantive Validation job count (validation_hours is
    # collected in collect_details); checks-only runs are excluded so a one-minute
    # agent check cannot masquerade as a faster Validation (#531). The retired
    # `Validation` workflow ran Validation on every run, so whole-run durations stay.
    durations = [run["validation_hours"] for run in groups["Pull Request"]
                 if run.get("validation_hours") is not None]
    durations += [hours(run["run_started_at"], run["updated_at"])
                  for run in groups["Validation"] if run.get("run_started_at")]
    metrics["ci.validation.median-hours"] = round(statistics.median(durations), 4) if durations else None
    return metrics


def agent_metrics(data):
    sessions = data["sessions"]
    metrics = {"agent.sessions": len(sessions)}
    for field in ("provider", "harness"):
        for value, count in Counter(key(str(row.get(field) or "unknown")) for row in sessions).items():
            metrics[f"agent.{field}.{value}"] = count
    runs = {row["run_id"] for row in data.get("window_ledger", data["ledger"]) if row.get("run_id") and
            (row.get("status") == "unavailable" or row.get("failure_kind") == "quota_exhausted"
             or row.get("reason") == "quota-exhausted")}
    metrics["agent.quota-or-unavailable-runs"] = len(runs)
    delivered = {row.get("session_id") for row in data["ledger"]
                 if row.get("prs") or (row.get("references") or {}).get("prs")
                 or re.search(r"\b(pushed|opened pr)\b", str(row.get("event") or row.get("summary") or row.get("message") or ""), re.I)}
    metrics["agent.closed-lanes-without-delivery"] = sum(
        row.get("status") in {"completed", "failed", "cancelled"} and row.get("issues")
        and not row.get("prs") and row["session_id"] not in delivered for row in data.get("ended_sessions", sessions)
    )
    metrics["agent.commits-missing-trailer"] = sum(
        not trailers.strip() for trailers in data["commit_trailers"]
    )
    return metrics


def compute_metrics(data, start, end):
    return (pr_metrics(data, start, end) | review_metrics(data["reviews"], data["runs"])
            | ci_metrics(data["runs"]) | agent_metrics(data))


def compare(metrics, previous):
    if previous is None:
        return {}, {}
    old = previous["metrics"]
    deltas = {metric: round(value - old[metric], 4) for metric, value in metrics.items()
              if value is not None and old.get(metric) is not None}
    statuses = {}
    for finding in previous["findings"]:
        metric = finding["metric_id"]
        value = metrics.get(metric)
        if value is None:
            # Per-PR metrics leave the window; absence is not evidence of no change.
            statuses[finding["id"]] = "not-observed"
            continue
        favorable = metric.endswith(".approved-share")
        delta = deltas.get(metric, 0) * (-1 if favorable else 1)
        if value == (1 if favorable else 0) and metric in deltas:
            status = "resolved"
        elif delta < 0:
            status = "improving"
        elif delta > 0:
            status = "regressed"
        else:
            status = "unchanged"
        statuses[finding["id"]] = status
    return deltas, statuses


def findings_from_model(payload, metrics):
    findings = {}
    entries = payload.get("findings") if isinstance(payload, dict) else None
    for entry in entries if isinstance(entries, list) else []:
        if not isinstance(entry, dict):
            continue
        metric = entry.get("metric_id")
        fields = ("title", "evidence", "recommendation", "acceptance")
        if not isinstance(metric, str) or metrics.get(metric) is None:
            continue
        if not all(isinstance(entry.get(field), str) and entry[field].strip() for field in fields):
            continue
        if metric not in re.findall(r"[a-z0-9]+(?:[.-][a-z0-9]+)+", entry["evidence"]):
            continue
        identifier = fingerprint(["agent-audit", metric])
        findings.setdefault(identifier, {
            "id": identifier, "metric_id": metric,
            **{field: " ".join(entry[field].split())[:500] for field in fields},
        })
        if len(findings) == 5:
            break
    return list(findings.values())


def apply_model(snapshot, result, payload):
    snapshot["model"] = {"status": result["status"], "resets_at": result.get("resets_at")}
    snapshot["findings"] = (findings_from_model(payload, snapshot["metrics"])
                            if result["status"] == "succeeded" else [])
    return snapshot


def repeated_findings(snapshot):
    # A deferred snapshot carries no metrics, findings or statuses.
    statuses = snapshot.get("statuses") or {}
    return [entry for entry in snapshot.get("findings") or []
            if statuses.get(entry["id"]) in {"unchanged", "regressed"}]


def gh_api(endpoint, *, pages=False, method="GET", data=None):
    args = ["gh", "api", "--method", method, endpoint]
    if pages:
        args += ["--paginate", "--slurp"]
    with tempfile.TemporaryDirectory(prefix="agent-audit-api-") as directory:
        if data is not None:
            body = Path(directory) / "request.json"
            save(body, data)
            args += ["--input", str(body)]
        result = subprocess.run(args, stdin=subprocess.DEVNULL, check=True,
                                capture_output=True, text=True)
    value = json.loads(result.stdout) if result.stdout else None
    if endpoint == "graphql" and value.get("errors"):
        raise RuntimeError("GitHub GraphQL rejected the audit operation")
    return value


def api_path(repo, suffix, **query):
    return f"repos/{repo}/{suffix}" + ("?" + urlencode(query) if query else "")


def pages(repo, suffix, *, field=None, **query):
    endpoint = api_path(repo, suffix, per_page=100, **query)
    try:
        result = gh_api(endpoint, pages=True)
    except subprocess.CalledProcessError as error:
        if "HTTP 403" not in error.stderr or "creator" in query:
            raise
        result = public_pages(endpoint)
    return [row for page in result for row in (page[field] if field else page)]


def public_pages(endpoint):
    url = "https://api.github.com/" + endpoint
    while url:
        request = Request(url, headers={"Accept": "application/vnd.github+json",
                                        "User-Agent": "foodsavr-audit"})
        with urlopen(request, timeout=15) as response:
            yield json.load(response)
            links = response.headers.get("Link", "")
        match = re.search(r'<(https://api\.github\.com/[^>]+)>; rel="next"', links)
        url = match[1] if match else None


def collect_sources(repo, start, end):
    # A folded session can be updated long after it started. Cohort on its start time.
    registrations = agentctl.records()
    sessions = [row for row in registrations if in_window(row.get("started_at"), start, end)]
    ended_sessions = [row for row in registrations if in_window(row.get("ended_at"), start, end)]
    ledger = [row for row in agentctl.ledger_rows()
              if (moment := agentctl.tr.record_time(row)) and moment <= end]
    reviews = [row for row in rows(Path(".agents/reviews/history.jsonl"))
               if row.get("type") == "review" and in_window(row.get("timestamp"), start, end)]
    candidates = pages(repo, "pulls", state="open")
    merged = []
    for index in range(1, 10000):
        page = gh_api(api_path(repo, "pulls", state="closed", sort="updated",
                              direction="desc", per_page=100, page=index))
        merged.extend(row for row in page if in_window(row.get("merged_at"), start, end))
        if not page or time(page[-1]["updated_at"]) <= start:
            break
    candidates = [pr for pr in candidates if time(pr["created_at"]) <= end]
    return {
        "sessions": sessions, "ended_sessions": ended_sessions, "ledger": ledger, "reviews": reviews,
        "open": candidates, "merged": merged,
    }


def git(*args, **kwargs):
    return subprocess.run(["git", *args], check=True, text=True, capture_output=True, **kwargs).stdout


def is_ancestor(ancestor, descendant):
    result = subprocess.run(["git", "merge-base", "--is-ancestor", ancestor, descendant],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0 if result.returncode < 2 else None


def count_behind(merge, candidates):
    """Count known heads based on the predecessor of a rebase merge."""
    tip = merge["merge_commit_sha"]
    try:
        base = git("rev-parse", f"{tip}~{merge['commits']}").strip()
    except (subprocess.CalledProcessError, TypeError):
        return None
    stamp = time(merge["merged_at"])
    count = 0
    for pr in candidates:
        if pr["number"] == merge["number"] or pr["base"]["ref"] != merge["base"]["ref"]:
            continue
        if time(pr["created_at"]) > stamp or (pr.get("merged_at") and time(pr["merged_at"]) <= stamp):
            continue
        # A later push would make the current head an unreliable historical observation.
        if any(event["event"] == "head_ref_force_pushed" and time(event["created_at"]) > stamp
                 for event in pr["timeline"]):
            continue
        head = pr["head"]["sha"]
        contains_base, contains_tip = is_ancestor(base, head), is_ancestor(tip, head)
        # An unresolvable head makes the count unknown, never zero.
        if contains_base is None or contains_tip is None:
            return None
        if contains_base and not contains_tip:
            count += 1
    return count


def job_log(repo, job_id):
    """Return a job's log text and whether log access is forbidden."""
    endpoint = api_path(repo, f"actions/jobs/{job_id}/logs")
    # Job logs carry ANSI colour codes, which recent gh refuses to print without this flag.
    logs = subprocess.run(["gh", "api", "--allow-escape-sequences", endpoint],
                          stdin=subprocess.DEVNULL, capture_output=True, text=True)
    if logs.returncode and "unknown flag" in logs.stderr:
        logs = subprocess.run(["gh", "api", endpoint],
                              stdin=subprocess.DEVNULL, capture_output=True, text=True)
    return ("" if logs.returncode else logs.stdout), "HTTP 403" in logs.stderr


def validation_hours(jobs) -> float | None:
    """Executed Validation-suite duration for one `Pull Request` run.

    None when no substantive Validation job ran (weekly agent check, `operation=checks`
    dispatch, or a reuse-only run), so checks-only runs stay out of the median (#531).
    """
    executed = [job for job in jobs
                if job.get("name") in VALIDATION_SUITE_JOBS
                and job.get("conclusion") not in (None, "skipped")
                and job.get("started_at") and job.get("completed_at")]
    if not any(job["name"] in VALIDATION_SUBSTANTIVE_JOBS for job in executed):
        return None
    return hours(min(job["started_at"] for job in executed),
                 max(job["completed_at"] for job in executed))


def collect_details(repo, data, start, end):
    runs = []
    # GitHub filters by creation date. Include a one-day overlap for in-flight runs.
    day_start = start - timedelta(days=1)
    while day_start < end:
        day_end = min(day_start + timedelta(days=1), end)
        date_range = f"{day_start.isoformat()}..{day_end.isoformat()}"
        runs.extend(run for run in pages(repo, "actions/runs", field="workflow_runs",
                                        created=date_range, status="completed")
                    if in_window(run["updated_at"], start, end))
        day_start = day_end
    runs = list({run["id"]: run for run in runs}.values())
    # Measure Validation itself, not the whole shared workflow: a Pull Request run
    # that skipped every substantive Validation job (the weekly agent-system check,
    # an `operation=checks` dispatch) is checks-only and must not count (#531).
    for run in runs:
        if run["name"] != "Pull Request":
            continue
        run["validation_hours"] = validation_hours(
            pages(repo, f"actions/runs/{run['id']}/jobs", field="jobs"))
    data["runs"] = runs
    rebases = Counter()
    held = set()
    logs_forbidden = False
    for run in runs:
        gate = run["path"].split("@")[0] == ".github/workflows/merge-gate.yml"
        if not gate and run["conclusion"] not in FAILURES:
            continue
        if gate and logs_forbidden:
            run["log_unavailable"] = True
            continue
        jobs = pages(repo, f"actions/runs/{run['id']}/jobs", field="jobs")
        for job in jobs:
            if not gate and job["conclusion"] not in FAILURES:
                continue
            evidence = ""
            if not logs_forbidden:
                evidence, logs_forbidden = job_log(repo, job["id"])
            if not evidence:
                run["log_unavailable"] = True
            if not evidence and not gate:
                try:
                    annotations = pages(repo, f"check-runs/{job['id']}/annotations")
                    evidence = "\n".join(annotation.get("message") or "" for annotation in annotations)
                except (HTTPError, subprocess.CalledProcessError):
                    pass
            run["maven_429"] = run.get("maven_429", False) or bool(
                re.search(r"maven.*\b429\b|\b429\b.*maven", evidence, re.I))
            if gate and evidence:
                actions = re.findall(r"#(\d+): update — ([^\r\n]+)", evidence)
                # A PR held through many gate runs is one removal, not one per run.
                held.update(re.findall(
                    r"\|\s*#(\d+)\s*\|\s*held\s*\|\s*merge/auto was removed", evidence))
                for number, outcome in actions:
                    if not outcome.startswith("failed") and "rebas" in outcome.lower():
                        rebases[int(number)] += 1
    data["held"] = len(held)
    for pr in data["merged"] + data["open"]:
        number = pr["number"]
        pr["timeline"] = pages(repo, f"issues/{number}/timeline")
        pr["rebases"] = max(rebases[number], sum(
            event["event"] == "head_ref_force_pushed"
            and in_window(event.get("created_at"), start, end)
            and (event.get("actor") or {}).get("login") == "foodsavr-release-gate[bot]"
            for event in pr["timeline"]))
        if pr.get("merged_at"):
            details = gh_api(api_path(repo, f"pulls/{number}"))
            actor = details.get("merged_by")
            pr["merge_bot"] = actor["type"] == "Bot" if actor else None
            pr["commits"] = details["commits"]
    # Scheduled runs have no GITHUB_BASE_REF. Fetch every head that shares a merged PR's base.
    bases = {pr["base"]["ref"] for pr in data["merged"]}
    for pr in data["merged"] + data["open"]:
        if pr["base"]["ref"] in bases:
            ref = f"refs/pull/{pr['number']}/head"
            subprocess.run(["git", "fetch", "--no-tags", "--quiet", "origin", ref],
                           capture_output=True, check=False)
    for pr in data["merged"]:
        pr["sent_behind"] = count_behind(pr, data["merged"] + data["open"])
    if any(run["path"].split("@")[0] == ".github/workflows/merge-gate.yml"
           and run.get("log_unavailable") for run in runs):
        removals = sum(event["event"] == "unlabeled"
                       and (event.get("label") or {}).get("name") == "merge/auto"
                       and in_window(event.get("created_at"), start, end)
                       for pr in data["merged"] + data["open"] for event in pr["timeline"])
        data["held"] = max(data["held"], removals)
    data["window_ledger"] = [row for row in data["ledger"]
                             if start < agentctl.tr.record_time(row) <= end]
    commits = git("log", "--format=%H%x00%(trailers:key=Agent-Session,valueonly)",
                  "--since-as-filter=" + start.isoformat(), "--until=" + end.isoformat())
    data["commit_trailers"] = [record.partition("\x00")[2] for record in commits.splitlines()
                               if "\x00" in record]


def collect(args):
    history = rows(HISTORY)
    run_id = os.environ["GITHUB_RUN_ID"]
    if existing := next((row for row in history if row["run_id"] == run_id), None):
        save(args.output, existing | {"already_published": True})
        return
    previous = previous_audit(history)
    end = datetime.now(timezone.utc).replace(microsecond=0)
    start = time(previous["end"]) if previous else (
        time(history[0]["start"]) if history else end - timedelta(days=1))
    repo = os.environ["GITHUB_REPOSITORY"]
    data = collect_sources(repo, start, end)
    sessions, merged = len(data["sessions"]), len(data["merged"])
    snapshot = {
        "run_id": run_id, "start": start.isoformat(), "end": end.isoformat(),
        "sessions": sessions, "merged": merged, "status": "deferred",
        "previous_run_id": previous["run_id"] if previous else None,
    }
    if threshold_met(sessions, merged, int(os.getenv("AUDIT_MIN_SESSIONS") or 10),
                     int(os.getenv("AUDIT_MIN_MERGED_PRS") or 5), args.force):
        collect_details(repo, data, start, end)
        metrics = compute_metrics(data, start, end)
        deltas, statuses = compare(metrics, previous)
        snapshot.update(status="completed", baseline=previous is None, metrics=metrics, deltas=deltas,
                        statuses=statuses, prior_findings=previous["findings"] if previous else [],
                        findings=[], model={"status": "unavailable", "resets_at": None})
    save(args.output, snapshot)


def provider_wrappers(directory):
    switches = {
        "codex": [flag for feature in (
            "shell_tool", "unified_exec", "incremental_tools", "plugins", "apps", "view_image",
            "image_generation", "sleep_tool", "computer_use", "browser_use", "multi_agent",
            "goals", "hooks", "skill_search",
        ) for flag in ("--disable", feature)] + ["-c", 'web_search="disabled"', "-c", "mcp_servers={}"],
        "claude": ["--tools", "", "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}'],
    }
    for provider, flags in switches.items():
        executable = shutil.which(provider)
        if executable is None:
            continue
        # Preserve version probes and keep the other provider's login out of Codex.
        unset = "unset CLAUDE_CODE_OAUTH_TOKEN\n" if provider == "codex" else ""
        path = directory / provider
        path.write_text("#!/bin/sh\n" + unset +
                        f'if [ "$1" = --version ]; then exec {shlex.quote(executable)} "$@"; fi\n' +
                        f'exec {shlex.quote(executable)} "$@" {shlex.join(flags)}\n')
        path.chmod(0o700)


def routed_result(stdout):
    """Read the router result. Malformed output leaves the deterministic report."""
    try:
        result = json.loads(stdout)
        status = result["status"]
    except (json.JSONDecodeError, TypeError, KeyError):
        return {"status": "unavailable"}, {}
    if not isinstance(status, str):
        return {"status": "unavailable"}, {}
    if status != "succeeded":
        return result, {}
    try:
        attempt = result["steps"][0]["attempts"][-1]
        artifact = json.loads(Path(attempt["artifact"]).read_text())
        response = artifact["review_output"].strip()
        payload = json.loads(re.sub(r"^\x60\x60\x60(?:json)?\s*|\s*\x60\x60\x60$", "", response))
    except (json.JSONDecodeError, OSError, TypeError, KeyError, IndexError, AttributeError):
        return result | {"status": "invalid-output"}, {}
    return result, payload


def model(path):
    snapshot = json.loads(path.read_text())
    if snapshot.get("already_published") or snapshot["status"] == "deferred":
        return
    original = WORKFLOW.read_text()
    workflow = json.loads(original)
    step = workflow["steps"][0]
    step["providers"] = [name for name in step["providers"] if shutil.which(name)]
    reset_at = []
    if "claude" in step["providers"]:
        quota = agentctl.hu.probe_all(["claude"], cache_dir=agentctl.QUOTA_CACHE)["claude"]
        now = agentctl.hu.utc_now()
        weekly = [window for window in quota.blocking_windows() if window.window_duration_mins == 10080]
        blocked = [window for window in weekly if window.is_exhausted(now, threshold=85)]
        if blocked or not weekly:
            step["providers"].remove("claude")
            reset_at.extend(window.resets_at for window in blocked if window.resets_at)
    result = {"status": "unavailable"}
    payload = {}
    if step["providers"]:
        model_data = {field: snapshot[field] for field in ("metrics", "deltas", "statuses", "prior_findings")}
        # Prior statements are model output from history. JSON delimiters keep them data.
        step["prompt"] += "\nAudit data (JSON):\n" + json.dumps(model_data, sort_keys=True)
        try:
            save(WORKFLOW, workflow)
            with tempfile.TemporaryDirectory(prefix="agent-audit-tools-") as temporary:
                provider_wrappers(Path(temporary))
                env = {**os.environ, "PATH": temporary + os.pathsep + os.environ["PATH"]}
                for name in ("GH_TOKEN", "GITHUB_TOKEN"):
                    env.pop(name, None)
                routed = subprocess.run(
                    ["scripts/agents/agentctl", "workflow", "run", str(WORKFLOW), "--execute"],
                    stdin=subprocess.DEVNULL, capture_output=True, text=True, env=env, check=False,
                )
            result, payload = routed_result(routed.stdout)
        finally:
            WORKFLOW.write_text(original)
    if result.get("resets_at"):
        reset_at.append(result["resets_at"])
    if result["status"] == "unavailable":
        result["resets_at"] = min(reset_at, key=time, default=None)
    save(path, apply_model(snapshot, result, payload))


def model_text(value):
    # GitHub preserves Markdown even after HTML escaping. Escape inline syntax as well.
    return re.sub(r"([\\\x60*_{}\[\]()#!|~])", r"\\\1", escape(value)).replace("@", "&#64;")


def finding_body(finding):
    return "\n".join([
        f"**{model_text(finding['title'])}** (`{finding['metric_id']}`)",
        "",
        model_text(finding["evidence"]),
        "",
        "**Recommendation** " + model_text(finding["recommendation"]),
        "",
        "**Acceptance** " + model_text(finding["acceptance"]),
    ])


def report(snapshot):
    if snapshot["status"] == "deferred":
        return (f"Audit deferred. The window has {snapshot['sessions']} new sessions "
                f"and {snapshot['merged']} merged PRs.")
    label = "Baseline" if snapshot["baseline"] else "Comparison with the previous audit"
    lines = [f"## {label}", "", f"{snapshot['start']} through {snapshot['end']}", "",
             "| Metric ID | Value | Delta |", "| --- | ---: | ---: |"]
    for metric, value in sorted(snapshot["metrics"].items()):
        delta = snapshot["deltas"].get(metric)
        lines.append(f"| `{metric}` | {value if value is not None else '—'} | "
                     f"{format(delta, '+g') if delta is not None else '—'} |")
    if snapshot["statuses"]:
        lines += ["", "### Previous recommendations", ""]
        for finding in snapshot["prior_findings"]:
            lines.append(f"- `{finding['metric_id']}` · {snapshot['statuses'][finding['id']]}")
    result = snapshot["model"]
    if result["status"] != "succeeded":
        return "\n".join(lines + ["", f"Model step skipped or incomplete ({model_text(result['status'])}). "
                                  f"Quota reset · {model_text(result['resets_at'] or 'unknown')}"])
    if snapshot["findings"]:
        lines += ["", "### Ranked findings"]
        repeated = {entry["id"] for entry in repeated_findings(snapshot)}
        for index, finding in enumerate(snapshot["findings"], 1):
            lines += ["", f"#### {index}. {'Repeated finding' if finding['id'] in repeated else 'Finding'}",
                      "", finding_body(finding)]
    return "\n".join(lines)


def comment_parts(markdown, limit=60000):
    chunk = []
    length = 0
    for line in markdown.splitlines(keepends=True):
        if chunk and length + len(line) > limit:
            yield "".join(chunk)
            chunk = []
            length = 0
        chunk.append(line)
        length += len(line)
    if chunk:
        yield "".join(chunk)


def bot_marker(issue, marker):
    return issue["user"]["login"] == BOT and (issue.get("body") or "").startswith(marker + "\n")


def current_snapshot(snapshot, history):
    if snapshot.get("already_published") or any(row["run_id"] == snapshot["run_id"] for row in history):
        return False
    previous = previous_audit(history)
    if snapshot["previous_run_id"] != (previous["run_id"] if previous else None):
        return False
    return not history or time(snapshot["end"]) > time(history[-1]["end"])


def publish(snapshot):
    fetch_history()
    if not current_snapshot(snapshot, rows(HISTORY)):
        return
    repo = os.environ["GITHUB_REPOSITORY"]
    issues = pages(repo, "issues", state="all", creator=BOT)
    endpoint = api_path(repo, "issues")
    marker = "<!-- agent-audit:tracking -->"
    tracking = next((issue for issue in issues if bot_marker(issue, marker)), None)
    if tracking is None:
        tracking = gh_api(endpoint, method="POST", data={
            "title": "Agent system audit log",
            "body": marker + "\nNightly reports from the agent-system audit.",
        })
    owner, name = repo.split("/")
    pinned = gh_api("graphql", method="POST", data={
        "query": """query($owner: String!, $name: String!) {
          repository(owner: $owner, name: $name) { pinnedIssues(first: 3) { nodes { issue { id } } } }
        }""",
        "variables": {"owner": owner, "name": name},
    })
    if tracking["node_id"] not in {node["issue"]["id"] for node in
                                   pinned["data"]["repository"]["pinnedIssues"]["nodes"]}:
        gh_api("graphql", method="POST", data={
            "query": "mutation($id: ID!) { pinIssue(input: {issueId: $id}) { issue { id } } }",
            "variables": {"id": tracking["node_id"]},
        })
    for finding in repeated_findings(snapshot):
        marker = f"<!-- agent-audit:finding:{finding['id']} -->"
        issue = next((item for item in issues if bot_marker(item, marker)), None)
        body = marker + "\n" + finding_body(finding)
        if issue:
            gh_api(f"{endpoint}/{issue['number']}", method="PATCH", data={"body": body})
        else:
            gh_api(endpoint, method="POST", data={"title": f"Agent audit finding {finding['id']}",
                   "body": body, "labels": ["triage/needs-triage", "area/agents"]})
    comments = f"issues/{tracking['number']}/comments"
    existing_comments = pages(repo, comments)
    for index, markdown in enumerate(comment_parts(report(snapshot)), 1):
        marker = f"<!-- agent-audit:run:{snapshot['run_id']}:{index} -->"
        body = marker + "\n" + markdown
        existing = next((item for item in existing_comments if bot_marker(item, marker)), None)
        if existing is None:
            gh_api(api_path(repo, comments), method="POST", data={"body": body})
        elif existing["body"] != body:
            gh_api(api_path(repo, f"issues/comments/{existing['id']}"), method="PATCH", data={"body": body})


def fetch_history():
    ref = f"refs/heads/{BRANCH}"
    if git("ls-remote", "--heads", "origin", ref).strip():
        git("fetch", "--depth=1", "origin", ref)
        HISTORY.parent.mkdir(parents=True, exist_ok=True)
        HISTORY.write_text(git("show", f"FETCH_HEAD:{HISTORY}"))
        return git("rev-parse", "FETCH_HEAD").strip()
    return None


def persist(snapshot):
    if snapshot.get("already_published"):
        return
    # Use a temporary index to build a commit on the history ref without checking it out.
    parent = fetch_history()
    if not current_snapshot(snapshot, rows(HISTORY)):
        return
    HISTORY.parent.mkdir(parents=True, exist_ok=True)
    with HISTORY.open("a", encoding="utf-8") as file:
        file.write(json.dumps(snapshot, sort_keys=True, allow_nan=False) + "\n")
    with tempfile.TemporaryDirectory(prefix="agent-audit-history-") as directory:
        env = {**os.environ, "GIT_INDEX_FILE": str(Path(directory) / "index")}
        if parent:
            git("read-tree", parent, env=env)
        git("add", "-f", str(HISTORY), env=env)
        tree = git("write-tree", env=env).strip()
        commit = git("-c", f"user.name={BOT}", "-c", "user.email=41898282+github-actions[bot]@users.noreply.github.com",
                     "commit-tree", tree, *(["-p", parent] if parent else []),
                     "-m", "chore(agents): record nightly audit",
                     "-m", f"Agent-Session: {agentctl.tr.detect_session().session_id}", env=env).strip()
        git("push", "origin", f"{commit}:refs/heads/{BRANCH}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_subparsers(dest="mode", required=True)
    modes.add_parser("load")
    collect_mode = modes.add_parser("collect")
    collect_mode.add_argument("output", type=Path)
    collect_mode.add_argument("--force", action="store_true")
    for mode in ("model", "verify-input", "publish", "persist"):
        command = modes.add_parser(mode)
        command.add_argument("snapshot", type=Path, nargs="?", default=Path(".agents/state/agent-audit.json"))
    args = parser.parse_args()
    if args.mode == "load":
        fetch_history()
    elif args.mode == "collect":
        collect(args)
    elif args.mode == "model":
        model(args.snapshot)
    else:
        snapshot = json.loads(args.snapshot.read_text())
        if args.mode == "verify-input":
            if snapshot["status"] != "completed" or not snapshot["metrics"]:
                parser.error("expected metrics from a completed collection")
        elif args.mode == "publish":
            publish(snapshot)
        else:
            persist(snapshot)


if __name__ == "__main__":
    main()
