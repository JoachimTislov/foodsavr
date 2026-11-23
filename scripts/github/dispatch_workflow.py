#!/usr/bin/env python3
"""Dispatch a workflow on a ref with your own gh login and print the run URL.

The manual bypass for pipeline steps that only exist as Actions workflows
(Validation, builds, Pages publish, Android Drive delivery, review re-runs).
Refuses workflows without a `workflow_dispatch` trigger instead of failing
late. Inputs are passed as `key=value` arguments.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github/workflows"


def has_dispatch(text: str) -> bool:
    """True when the workflow's `on:` block lists workflow_dispatch."""
    return re.search(r"^\s*workflow_dispatch\s*:", text, re.MULTILINE) is not None


def resolve(workflow: str) -> Path:
    name = workflow if workflow.endswith((".yml", ".yaml")) else f"{workflow}.yml"
    path = WORKFLOWS / name
    if not path.is_file():
        available = ", ".join(sorted(p.name for p in WORKFLOWS.glob("*.yml") if has_dispatch(p.read_text())))
        raise SystemExit(f"error: no workflow {name}; dispatchable: {available}")
    if not has_dispatch(path.read_text()):
        raise SystemExit(f"error: {name} has no workflow_dispatch trigger; it only runs on its events")
    return path


def parse_inputs(pairs: list[str]) -> list[str]:
    for pair in pairs:
        if "=" not in pair or pair.startswith("="):
            raise SystemExit(f"error: input '{pair}' must look like key=value")
    return pairs


def gh(*args: str) -> str:
    result = subprocess.run(["gh", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"error: gh {args[0]} failed: {result.stderr.strip()}")
    return result.stdout


def find_run(workflow: str, ref: str, since: datetime, attempts: int = 10) -> str | None:
    for _ in range(attempts):
        runs = json.loads(gh("run", "list", "--workflow", workflow, "--branch", ref, "--event", "workflow_dispatch",
                             "--limit", "5", "--json", "url,createdAt"))
        for run in runs:
            if datetime.fromisoformat(run["createdAt"].replace("Z", "+00:00")) >= since:
                return run["url"]
        time.sleep(3)
    return None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workflow", help="workflow file name, with or without .yml")
    parser.add_argument("--ref", required=True, help="branch or tag to run the workflow on")
    parser.add_argument("--input", "-f", action="append", default=[], metavar="KEY=VALUE")
    args = parser.parse_args(argv)
    path = resolve(args.workflow)
    inputs = parse_inputs(args.input)
    since = datetime.now(timezone.utc).replace(microsecond=0)
    cmd = ["workflow", "run", path.name, "--ref", args.ref]
    for pair in inputs:
        cmd += ["-f", pair]
    gh(*cmd)
    print(f"Dispatched {path.name} on {args.ref}.")
    url = find_run(path.name, args.ref, since)
    print(url or f"Run not visible yet; see `gh run list --workflow {path.name}`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
