"""Find active GitHub Actions workflows whose files are gone from the default branch."""

from typing import Any

WORKFLOWS_ENDPOINT = "actions/workflows?per_page=100"
DEFAULT_BRANCH_TREE_ENDPOINT = "git/trees/HEAD?recursive=1"


def active_orphaned_workflows(workflows: Any, default_tree: Any) -> dict[int, str]:
    """Return IDs and names from complete, readable default-branch tree data."""
    if not isinstance(workflows, dict) or not isinstance(workflows.get("workflows"), list):
        raise ValueError("GitHub workflow inventory is unavailable.")
    if not (
        isinstance(default_tree, dict)
        and default_tree.get("truncated") is False
        and isinstance(default_tree.get("tree"), list)
    ):
        raise ValueError("GitHub default-branch file tree is unavailable or incomplete.")

    tracked = {entry["path"] for entry in default_tree["tree"] if entry["type"] == "blob"}
    orphans: dict[int, str] = {}
    for workflow in workflows["workflows"]:
        if not isinstance(workflow, dict) or workflow.get("state") != "active":
            continue
        path = workflow.get("path")
        workflow_id = workflow.get("id")
        if isinstance(workflow_id, int) and isinstance(path, str):
            if path.startswith(".github/workflows/") and path not in tracked:
                orphans[workflow_id] = workflow.get("name") or path
    return orphans
