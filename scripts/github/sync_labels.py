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
_LABELS_ENSURED = False


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
    labels: set[str] = set()
    legacy_map = config.get("legacy_label_map", {})
    existing_labels = {label["name"] for label in item.get("labels", [])}
    type_label = next((legacy_map[label] for label in existing_labels if label in legacy_map and legacy_map[label] and legacy_map[label].startswith("type/")), None)
    type_rules = config.get("title_body_rules", [])
    type_label = type_label or next((rule["label"] for rule in type_rules if matches(item.get("title", ""), rule["patterns"])), None)
    type_label = type_label or ("type/task" if item.get("is_pull_request") else "type/task")
    labels.add(type_label)
    # Agent event logs and the frozen legacy logs ride along with every PR; they say nothing about its area.
    files = [path for path in files if not path.startswith(tuple(config.get("ignored_paths", [])))]
    area_matches = {
        rule["label"] for rule in config.get("path_rules", [])
        if any(matches(path, rule["patterns"]) for path in files)
    }
    for legacy in existing_labels:
        mapped = legacy_map.get(legacy)
        if mapped and mapped.startswith("area/"):
            area_matches.add(mapped)
    if area_matches:
        for label in config.get("area_priority", []):
            if label in area_matches:
                labels.add(label)
                break
    for rule in config.get("risk_rules", []):
        if any(matches(path, rule["patterns"]) for path in files):
            labels.add(rule["label"])
    if item.get("is_pull_request"):
        conclusions = {check.get("conclusion") for check in checks if check.get("status") == "completed"}
        pending = any(check.get("status") != "completed" for check in checks)
        if any(conclusion in {"failure", "cancelled", "timed_out", "action_required"} for conclusion in conclusions):
            labels.add("status/ci-failing")
        elif pending:
            labels.add("status/ci-pending")
    else:
        configured_labels = {label["name"] for label in config.get("labels", [])}
        labels.update(
            label for label in existing_labels & configured_labels
            if label.startswith(("area/", "risk/"))
        )
    return labels


def is_managed(name: str, prefixes: list[str]) -> bool:
    return any(name.startswith(prefix) for prefix in prefixes)


def stale_labels(current: set[str], config: dict[str, Any]) -> set[str]:
    legacy = set(config.get("legacy_label_map", {}))
    return {label for label in current if is_managed(label, config.get("managed_prefixes", [])) or label in legacy}


def apply_labels(repo: str, number: int, current: set[str], desired: set[str], config: dict[str, Any]) -> dict[str, list[str]]:
    global _LABELS_ENSURED
    if not _LABELS_ENSURED:
        for label in config.get("labels", []):
            try:
                subprocess.run(
                    ["gh", "api", f"repos/{repo}/labels", "-X", "POST", "-f", f"name={label['name']}", "-f", f"color={label['color']}", "-f", f"description={label['description']}"],
                    cwd=ROOT, capture_output=True, text=True, check=True,
                )
            except subprocess.CalledProcessError:
                # Existing labels are idempotent; any real failure is surfaced by the issue edit below.
                pass
        _LABELS_ENSURED = True
    add = sorted(desired - current)
    stale = stale_labels(current, config)
    remove = sorted(stale - desired)
    final_labels = sorted((current - stale) | desired)
    subprocess.run(
        ["gh", "api", f"repos/{repo}/issues/{number}/labels", "-X", "PUT", "--input", "-"],
        input=json.dumps({"labels": final_labels}), text=True, cwd=ROOT, capture_output=True, check=True,
    )
    return {"added": add, "removed": remove}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo")
    parser.add_argument("--number", type=int)
    parser.add_argument("--sha")
    parser.add_argument("--all-open", action="store_true", help="sync every currently open issue and pull request")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args(argv)
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    repo = repo_name(args.repo)
    if args.all_open:
        if args.number or args.sha:
            parser.error("--all-open cannot be combined with --number or --sha")
        results = []
        for item in gh_json(repo, "issues?state=open&per_page=100"):
            number = item["number"]
            current_item, files, checks, reviews = item_and_context(repo, number, None)
            current = {label["name"] for label in current_item.get("labels", [])}
            desired = classify(current_item, files, checks, reviews, config)
            changes = apply_labels(repo, number, current, desired, config) if args.apply else {"added": sorted(desired - current), "removed": sorted(stale_labels(current, config) - desired)}
            results.append({"number": number, "desired": sorted(desired), "changes": changes})
        print(json.dumps({"repo": repo, "count": len(results), "applied": args.apply, "items": results}, indent=2, sort_keys=True))
        return 0
    item, files, checks, reviews = item_and_context(repo, args.number, args.sha)
    current = {label["name"] for label in item.get("labels", [])}
    desired = classify(item, files, checks, reviews, config)
    changes = apply_labels(repo, item["number"], current, desired, config) if args.apply else {
        "added": sorted(desired - current),
        "removed": sorted(stale_labels(current, config) - desired),
    }
    print(json.dumps({"repo": repo, "number": item["number"], "desired": sorted(desired), "changes": changes, "applied": args.apply}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
