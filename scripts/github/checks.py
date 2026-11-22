"""Shared GitHub check-run and status-context evaluation for merge_gate and promote_release."""

from __future__ import annotations

from typing import Any

QUEUE_CHECK = "Detect changed areas"
IGNORED_WORKFLOWS = {
    "Merge gate",
    "Agent review",
    "Synchronize GitHub labels",
    "Promote develop to main",
    "Promote release channels",
}
FAILED = {"FAILURE", "ERROR", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STARTUP_FAILURE"}


def rollup_state(contexts: list[dict[str, Any]]) -> str | None:
    """Aggregate head checks like GitHub's rollup, excluding metadata workflows."""
    states = []
    for c in contexts:
        if c.get("__typename") == "CheckRun":
            workflow = (((c.get("checkSuite") or {}).get("workflowRun") or {}).get("workflow") or {}).get("name")
            if workflow in IGNORED_WORKFLOWS:
                continue
            states.append(
                "PENDING"
                if c.get("status") != "COMPLETED"
                else "FAILURE"
                if c.get("conclusion") in FAILED
                else "SUCCESS"
            )
        elif c.get("__typename") == "StatusContext":
            states.append(
                {"SUCCESS": "SUCCESS", "PENDING": "PENDING", "EXPECTED": "PENDING"}.get(c.get("state"), "FAILURE")
            )
    if not states:
        return None
    return "FAILURE" if "FAILURE" in states else "PENDING" if "PENDING" in states else "SUCCESS"


TRUSTED_CHECK_APPS = {"github-actions"}


def _is_trusted_queue_check(context: dict[str, Any]) -> bool:
    if context.get("__typename") != "CheckRun" or context.get("name") != QUEUE_CHECK:
        return False
    app = (context.get("checkSuite") or {}).get("app")
    if isinstance(app, dict):
        slug = app.get("slug")
        if slug not in TRUSTED_CHECK_APPS:
            return False
    return True


def queue_check_state(contexts: list[dict[str, Any]]) -> tuple[bool, bool]:
    """Return (completed_success, running) for the merge-queue Validation entrypoint."""
    runs = [c for c in contexts if _is_trusted_queue_check(c)]
    ok = any(c.get("status") == "COMPLETED" and c.get("conclusion") == "SUCCESS" for c in runs)
    running = any(c.get("status") != "COMPLETED" for c in runs)
    return ok, running
