#!/usr/bin/env python3
"""Synchronize declarative, namespaced GitHub labels for an issue or PR."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / ".agents/github/labels.json"
MANAGED_LABEL = "automation/agent-managed"


def gh_json(repo: str, endpoint: str) -> Any:
    result = subprocess.run(
        ["gh", "api", f"repos/{repo}/{endpoint}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def repo_name(value: str | None) -> str:
    if value:
        return value
    if os.environ.get("GH_REPO"):
        return os.environ["GH_REPO"]
    result = subprocess.run(["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"], cwd=ROOT, capture_output=True, text=True, check=True)
    return result.stdout.strip()


def item_and_context(repo: str, number: int | None, sha: str | None) -> tuple[dict[str, Any], list[str], list[dict[str, Any]], list[dict[str, Any]]]:
    if number is None and sha:
        pulls = gh_json(repo, f"commits/{sha}/pulls?per_page=20")
        number = pulls[0]["number"] if pulls else None
    if number is None:
        raise ValueError("an issue/PR number or commit SHA is required")
    issue = gh_json(repo, f"issues/{number}")
    is_pr = "pull_request" in issue
    item = issue
    files: list[str] = []
    checks: list[dict[str, Any]] = []
    reviews: list[dict[str, Any]] = []
    if is_pr:
        pull = gh_json(repo, f"pulls/{number}")
        item = {**issue, **pull, "is_pull_request": True}
        files = [file["filename"] for file in gh_json(repo, f"pulls/{number}/files?per_page=100")]
        head_sha = pull["head"]["sha"]
        checks = gh_json(repo, f"commits/{head_sha}/check-runs?per_page=100").get("check_runs", [])
        reviews = gh_json(repo, f"pulls/{number}/reviews?per_page=100")
    else:
        item["is_pull_request"] = False
    return item, files, checks, reviews


def matches(text: str, patterns: list[str]) -> bool:
    return any(re.search(pattern, text, re.IGNORECASE) for pattern in patterns)


def classify(item: dict[str, Any], files: list[str], checks: list[dict[str, Any]], reviews: list[dict[str, Any]], config: dict[str, Any]) -> set[str]:
    text = f"{item.get('title', '')}\n{item.get('body', '')}"
    labels: set[str] = {MANAGED_LABEL}
    type_rules = config.get("title_body_rules", [])
    type_label = next((rule["label"] for rule in type_rules if matches(text, rule["patterns"])), "type/maintenance" if item.get("is_pull_request") else "type/task")
    labels.add(type_label)
    for rule in config.get("path_rules", []):
        if any(matches(path, rule["patterns"]) for path in files):
            labels.add(rule["label"])
    for rule in config.get("risk_rules", []):
        if any(matches(path, rule["patterns"]) for path in files) or matches(text, rule["patterns"]):
            labels.add(rule["label"])
    if item.get("is_pull_request"):
        labels.add("status/draft" if item.get("draft") else "status/ready")
        review_states = {review.get("state", "").upper() for review in reviews}
        if "CHANGES_REQUESTED" in review_states:
            labels.add("status/changes-requested")
        elif review_states:
            labels.add("status/review")
        conclusions = {check.get("conclusion") for check in checks if check.get("status") == "completed"}
        pending = any(check.get("status") != "completed" for check in checks)
        if any(conclusion in {"failure", "cancelled", "timed_out", "action_required"} for conclusion in conclusions):
            labels.add("status/ci-failing")
        elif pending or not checks:
            labels.add("status/ci-pending")
        else:
            labels.add("status/ci-green")
    else:
        labels.add("status/open" if item.get("state") == "open" else "status/closed")
    return labels


def is_managed(name: str, prefixes: list[str]) -> bool:
    return any(name.startswith(prefix) for prefix in prefixes)


def apply_labels(repo: str, number: int, current: set[str], desired: set[str], config: dict[str, Any]) -> dict[str, list[str]]:
    for label in config.get("labels", []):
        try:
            subprocess.run(
                ["gh", "api", f"repos/{repo}/labels", "-X", "POST", "-f", f"name={label['name']}", "-f", f"color={label['color']}", "-f", f"description={label['description']}"],
                cwd=ROOT, capture_output=True, text=True, check=True,
            )
        except subprocess.CalledProcessError:
            # Existing labels are idempotent; any real failure is surfaced by the issue edit below.
            pass
    add = sorted(desired - current)
    remove = sorted(label for label in current if is_managed(label, config.get("managed_prefixes", [])) and label not in desired)
    for label in add:
        subprocess.run(["gh", "issue", "edit", str(number), "--repo", repo, "--add-label", label], cwd=ROOT, check=True)
    for label in remove:
        subprocess.run(["gh", "issue", "edit", str(number), "--repo", repo, "--remove-label", label], cwd=ROOT, check=True)
    return {"added": add, "removed": remove}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo")
    parser.add_argument("--number", type=int)
    parser.add_argument("--sha")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args(argv)
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    repo = repo_name(args.repo)
    item, files, checks, reviews = item_and_context(repo, args.number, args.sha)
    current = {label["name"] for label in item.get("labels", [])}
    desired = classify(item, files, checks, reviews, config)
    changes = apply_labels(repo, item["number"], current, desired, config) if args.apply else {
        "added": sorted(desired - current),
        "removed": sorted(label for label in current if is_managed(label, config.get("managed_prefixes", [])) and label not in desired),
    }
    print(json.dumps({"repo": repo, "number": item["number"], "desired": sorted(desired), "changes": changes, "applied": args.apply}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
