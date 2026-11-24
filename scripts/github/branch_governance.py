"""Required checks from the desired default-branch GitHub ruleset."""

import json
from pathlib import Path

DEFAULT_BRANCH_RULESET = Path(__file__).resolve().parents[2] / ".agents/github/default-branch-ruleset.json"


def default_branch_required_checks() -> tuple[str, ...]:
    ruleset = json.loads(DEFAULT_BRANCH_RULESET.read_text(encoding="utf-8"))
    return tuple(
        check["context"]
        for rule in ruleset["rules"]
        if rule["type"] == "required_status_checks"
        for check in rule["parameters"]["required_status_checks"]
    )
