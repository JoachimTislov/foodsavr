"""Shared GitHub check-run and status-context evaluation for merge_gate and promote_release."""

from __future__ import annotations

from datetime import datetime
from typing import Any

QUEUE_CHECK = "Detect changed areas"
# This is an informational attestation status, not an independent required check.
# The review evaluator is the authority and binds approval to the head SHA.
IGNORED_STATUSES = {"Review verdict"}
ANY_JOB = "*"
# (workflow, job) check runs. Agent Ops and Ops & Maintenance also run jobs whose
# failures must count (implementation, audit, monitoring), so they match by job.
# Names of the workflows retired by #496 stay for runs still on older heads.
REVIEW_CHECKS: frozenset[tuple[str, str]] = frozenset({
    ("Agent Ops", "Adaptive PR review"),
    ("Agent Ops", "Record review and attest"),
    ("Agent review", ANY_JOB),
})
IGNORED_CHECKS: frozenset[tuple[str, str]] = REVIEW_CHECKS | frozenset({
    ("Merge gate", ANY_JOB),
    ("Agent Ops", "Wake the merge gate"),
    ("Ops & Maintenance", "Synchronize GitHub labels"),
    ("Release", "Fast-forward release channel"),
    ("Synchronize GitHub labels", ANY_JOB),
    ("Promote develop to main", ANY_JOB),
    ("Promote release channels", ANY_JOB),
})
FAILED = {"FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"}


def _workflow_name(context: dict[str, Any]) -> str | None:
    return (((context.get("checkSuite") or {}).get("workflowRun") or {}).get("workflow") or {}).get("name")


def _matches(context: dict[str, Any], checks: frozenset[tuple[str, str]]) -> bool:
    workflow = _workflow_name(context)
    return (workflow, ANY_JOB) in checks or (workflow, context.get("name")) in checks


def is_ignored(context: dict[str, Any]) -> bool:
    """True for metadata check runs (merge gate, review, label sync, promotion) outside rollups."""
    return context.get("__typename") == "CheckRun" and _matches(context, IGNORED_CHECKS)


def is_review(context: dict[str, Any]) -> bool:
    """True for adaptive review check runs (review and attestation jobs)."""
    return context.get("__typename") == "CheckRun" and _matches(context, REVIEW_CHECKS)


def _key(context: dict[str, Any]) -> tuple[str | None, ...]:
    if context.get("__typename") == "StatusContext":
        return ("status", context.get("context"))
    return ("run", _workflow_name(context), context.get("name"))


def _is_skipped(context: dict[str, Any]) -> bool:
    return context.get("status") == "COMPLETED" and context.get("conclusion") == "SKIPPED"


def _workflow_run_id(context: dict[str, Any]) -> int | None:
    value = ((context.get("checkSuite") or {}).get("workflowRun") or {}).get("databaseId")
    return int(value) if value is not None else None


def _started(context: dict[str, Any]) -> datetime | None:
    value = context.get("startedAt")
    return datetime.fromisoformat(value.replace("Z", "+00:00")) if value else None


def effective_runs(contexts: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Keep the run that decides each check: workflow and check name, or status context name.

    The latest run by startedAt wins, but a SKIPPED run never supersedes a run that executed
    (label-only events create newer runs whose jobs are skipped); when every run of a key is
    skipped, the latest skipped one is used. A key with any run lacking startedAt keeps all of
    its runs, so callers whose query omits startedAt evaluate every run as before.

    A CANCELLED run is dropped when a newer run of the same workflow (higher workflow-run
    databaseId on this head) exists: concurrency cancellation supersedes it, even if the newer
    run skipped that job. A CANCELLED run with no newer workflow run still counts as cancelled.
    """
    groups: dict[tuple[str | None, ...], list[dict[str, Any]]] = {}
    for c in contexts:
        groups.setdefault(_key(c), []).append(c)
    keep: list[dict[str, Any]] = []
    for runs in groups.values():
        times = [_started(c) for c in runs]
        if len(runs) == 1 or any(t is None for t in times):
            keep.extend(runs)
            continue
        executed = [(t, c) for t, c in zip(times, runs) if not _is_skipped(c)]
        pool = executed or list(zip(times, runs))
        latest = max(t for t, _ in pool)
        keep.extend(c for t, c in pool if t == latest)
    newest: dict[str | None, int] = {}
    for c in contexts:
        run_id = _workflow_run_id(c)
        if c.get("__typename") == "CheckRun" and run_id is not None:
            name = _workflow_name(c)
            newest[name] = max(newest.get(name, run_id), run_id)

    def superseded(c: dict[str, Any]) -> bool:
        run_id = _workflow_run_id(c)
        return (
            c.get("__typename") == "CheckRun"
            and c.get("conclusion") == "CANCELLED"
            and run_id is not None
            and run_id < newest[_workflow_name(c)]
        )

    return [c for c in contexts if any(c is k for k in keep) and not superseded(c)]


def rollup_state(contexts: list[dict[str, Any]]) -> str | None:
    """Aggregate head checks like GitHub's rollup, excluding metadata workflows."""
    states = []
    for c in effective_runs(contexts):
        if c.get("__typename") == "CheckRun":
            if is_ignored(c):
                continue
            states.append(
                "PENDING"
                if c.get("status") != "COMPLETED"
                else "FAILURE"
                if c.get("conclusion") in FAILED
                else "SUCCESS"
            )
        elif c.get("__typename") == "StatusContext" and c.get("context") not in IGNORED_STATUSES:
            states.append(
                {"SUCCESS": "SUCCESS", "PENDING": "PENDING", "EXPECTED": "PENDING"}.get(c.get("state"), "FAILURE")
            )
    if not states:
        return None
    return "FAILURE" if "FAILURE" in states else "PENDING" if "PENDING" in states else "SUCCESS"


TRUSTED_CHECK_APPS = {"github-actions"}


def _is_trusted_actions_check(context: dict[str, Any]) -> bool:
    if context.get("__typename") != "CheckRun":
        return False
    app = (context.get("checkSuite") or {}).get("app")
    if isinstance(app, dict):
        slug = app.get("slug")
        if slug not in TRUSTED_CHECK_APPS:
            return False
    return True


def _is_trusted_queue_check(context: dict[str, Any]) -> bool:
    return _is_trusted_actions_check(context) and context.get("name") == QUEUE_CHECK


def queue_check_state(contexts: list[dict[str, Any]]) -> tuple[bool, bool]:
    """Return (completed_success, running) for the merge-queue Validation entrypoint."""
    runs = effective_runs([c for c in contexts if _is_trusted_queue_check(c)])
    ok = any(c.get("status") == "COMPLETED" and c.get("conclusion") == "SUCCESS" for c in runs)
    running = any(c.get("status") != "COMPLETED" for c in runs)
    return ok, running


def review_check_state(contexts: list[dict[str, Any]]) -> tuple[bool, datetime | None]:
    """Return (running, started_at) for active trusted Agent review check runs on this head."""
    runs = effective_runs([
        c for c in contexts
        if _is_trusted_actions_check(c) and is_review(c)
    ])
    active = [c for c in runs if c.get("status") != "COMPLETED"]
    if not active:
        return False, None
    starts = [t for c in active if (t := _started(c)) is not None]
    return True, (max(starts) if starts else None)


def review_check_running(contexts: list[dict[str, Any]]) -> bool:
    """Return True when a trusted adaptive review check run is active on this head."""
    return review_check_state(contexts)[0]
