#!/usr/bin/env python3
"""Agent-native repository context, session, and knowledge catalog CLI."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sqlite3
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / ".agents/sessions/index.jsonl"
SCHEMA = ROOT / ".agents/knowledge/schema.sql"
DATABASE = ROOT / ".agents/state/knowledge.sqlite3"
RUNNERS = ROOT / ".agents/runners/providers.json"
POLICY = ROOT / ".agents/policies/default.json"
TEXT_SUFFIXES = {".md", ".markdown", ".yaml", ".yml", ".json", ".toml"}
EXCLUDED_PARTS = {".git", ".dart_tool", "build", "state"}
URL_RE = re.compile(r"https?://[^\s)\]>]+")
ISSUE_RE = re.compile(r"(?<![\w])#\d+")
SHA_RE = re.compile(r"(?<![0-9a-f])[0-9a-f]{7,40}(?![0-9a-f])", re.I)


def now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def records(index: Path = INDEX) -> list[dict[str, Any]]:
    if not index.exists():
        return []
    result = []
    for number, line in enumerate(index.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(f"{index}:{number}: invalid JSON: {error}") from error
        if not isinstance(value, dict):
            raise ValueError(f"{index}:{number}: record must be an object")
        result.append(value)
    return result


def connect(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    connection.executescript(SCHEMA.read_text(encoding="utf-8"))
    return connection


def document_paths() -> list[Path]:
    roots = [ROOT / name for name in ("AGENTS.md", "README.md", "TODO.md", "INDEX.md", "doc", "docs", "specs", ".agents")]
    result: set[Path] = set()
    for root in roots:
        if root.is_file() and root.suffix in TEXT_SUFFIXES:
            result.add(root)
        elif root.is_dir():
            for path in root.rglob("*"):
                if path.is_symlink() or not path.is_file() or path.suffix not in TEXT_SUFFIXES:
                    continue
                relative_parts = path.relative_to(ROOT).parts
                if EXCLUDED_PARTS.intersection(relative_parts) or relative_parts[:1] == ("research",):
                    continue
                result.add(path)
    return sorted(result)


def document_kind(path: Path) -> str:
    relative = path.relative_to(ROOT).as_posix()
    if relative.startswith("specs/"):
        return "spec"
    if relative.startswith(".agents/"):
        return "agent"
    if relative.startswith(("docs/", "doc/")):
        return "documentation"
    return "entrypoint"


def document_title(path: Path, content: str) -> str:
    for line in content.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return path.stem.replace("-", " ").replace("_", " ").title()


def references(content: str) -> list[tuple[str, str]]:
    found: set[tuple[str, str]] = set()
    found.update(("github_reference", value) for value in ISSUE_RE.findall(content))
    found.update(("url", value.rstrip(".,;:")) for value in URL_RE.findall(content))
    found.update(("commit_or_id", value) for value in SHA_RE.findall(content))
    return sorted(found)


def rebuild(args: argparse.Namespace, emit: bool = True) -> int:
    database = Path(args.database).expanduser()
    connection = connect(database)
    paths = document_paths()
    session_records = records()
    with connection:
        for table in ("document_search", "document_references", "documents", "session_references", "sessions"):
            connection.execute(f"DELETE FROM {table}")
        for path in paths:
            content = path.read_text(errors="replace")
            relative = path.relative_to(ROOT).as_posix()
            cursor = connection.execute(
                "INSERT INTO documents(path, kind, title, content, sha256, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
                (relative, document_kind(path), document_title(path, content), content,
                 hashlib.sha256(content.encode()).hexdigest(), now()),
            )
            connection.executemany(
                "INSERT INTO document_references(document_id, ref_type, ref_value) VALUES (?, ?, ?)",
                [(cursor.lastrowid, ref_type, value) for ref_type, value in references(content)],
            )
        for record in session_records:
            session_id = record.get("session_id")
            if not session_id:
                continue
            connection.execute(
                "INSERT INTO sessions(session_id, provider, harness, started_at, status, summary, transcript, raw_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                (session_id, record.get("provider", "unknown"), record.get("harness", "unknown"),
                 record.get("started_at", ""), record.get("status", "unknown"),
                 record.get("summary", ""), record.get("transcript"), json.dumps(record, sort_keys=True)),
            )
            for field in ("issues", "prs", "sources", "commits"):
                connection.executemany(
                    "INSERT OR IGNORE INTO session_references(session_id, ref_type, ref_value) VALUES (?, ?, ?)",
                    [(session_id, field[:-1], str(value)) for value in record.get(field, [])],
                )
        connection.execute("INSERT INTO document_search(document_search) VALUES ('rebuild')")
    if emit:
        print(json.dumps({"database": str(database), "documents": len(paths), "sessions": len(session_records)}))
    return 0


def search_phrase(term: str) -> str:
    terms = [part for part in term.split() if part]
    return " OR ".join(f'"{part.replace(chr(34), chr(34) * 2)}"' for part in terms)


def ensure_catalog(connection: sqlite3.Connection) -> None:
    rows = connection.execute("SELECT path, sha256 FROM documents").fetchall()
    if not rows:
        raise ValueError("knowledge catalog is empty; run `scripts/agents/agentctl knowledge rebuild`")
    for row in rows:
        path = ROOT / row["path"]
        if not path.exists():
            raise ValueError(f"knowledge catalog is stale; missing source {row['path']}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != row["sha256"]:
            raise ValueError(f"knowledge catalog is stale; rebuild after changing {row['path']}")


def query(args: argparse.Namespace) -> int:
    connection = connect(Path(args.database).expanduser())
    ensure_catalog(connection)
    rows = connection.execute(
        "SELECT title, path, snippet(document_search, 1, '[', ']', '…', 24) AS snippet, bm25(document_search) AS rank "
        "FROM document_search WHERE document_search MATCH ? ORDER BY rank LIMIT ?",
        (search_phrase(args.term), args.limit),
    ).fetchall()
    print(json.dumps([dict(row) for row in rows], indent=2))
    return 0


def context(args: argparse.Namespace) -> int:
    connection = connect(Path(args.database).expanduser())
    ensure_catalog(connection)
    docs = connection.execute(
        "SELECT title, path, snippet(document_search, 1, '[', ']', '…', 20) AS snippet "
        "FROM document_search WHERE document_search MATCH ? ORDER BY bm25(document_search) LIMIT ?",
        (search_phrase(args.term), args.limit),
    ).fetchall()
    session_rows = connection.execute(
        "SELECT session_id, provider, harness, status, summary FROM sessions ORDER BY started_at DESC"
    ).fetchall()
    terms = [term.casefold() for term in args.term.split() if term]
    sessions = [
        row for row in session_rows
        if any(term in f"{row['session_id']} {row['summary']}".casefold() for term in terms)
    ][:args.limit]
    print(json.dumps({"term": args.term, "documents": [dict(row) for row in docs], "sessions": [dict(row) for row in sessions]}, indent=2))
    return 0


def session_list(args: argparse.Namespace) -> int:
    result = records(Path(args.index).expanduser())
    if args.provider:
        result = [row for row in result if row.get("provider") == args.provider]
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


def session_register(args: argparse.Namespace) -> int:
    index = Path(args.index).expanduser()
    current = records(index)
    if any(row.get("session_id") == args.session_id for row in current):
        raise ValueError(f"session already registered: {args.session_id}")
    record: dict[str, Any] = {
        "session_id": args.session_id, "provider": args.provider, "harness": args.harness,
        "started_at": args.started_at or now(), "status": args.status, "issues": args.issue,
        "prs": args.pr, "sources": args.source, "commits": args.commit, "summary": args.summary,
    }
    if args.transcript:
        record["transcript"] = args.transcript
    index.parent.mkdir(parents=True, exist_ok=True)
    with index.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(record, sort_keys=True) + "\n")
    print(json.dumps(record, indent=2, sort_keys=True))
    return 0


def provider_specs() -> dict[str, dict[str, Any]]:
    return load_json(RUNNERS).get("providers", {})


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read JSON {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{path}: root must be an object")
    return value


def validate_workflow_file(path: Path) -> list[str]:
    workflow = load_json(path)
    errors = []
    allowed = {"schema_version", "id", "objective", "context", "steps", "limits", "permissions", "outputs"}
    errors.extend(f"{path}: unknown field {field}" for field in workflow if field not in allowed)
    for field in ("schema_version", "id", "objective", "steps", "limits", "permissions"):
        if field not in workflow:
            errors.append(f"{path}: missing {field}")
    if workflow.get("schema_version") != 1:
        errors.append(f"{path}: schema_version must be 1")
    if not isinstance(workflow.get("id"), str) or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", str(workflow.get("id"))):
        errors.append(f"{path}: id must match ^[a-z0-9][a-z0-9-]*$")
    context = workflow.get("context", {})
    if not isinstance(context, dict):
        errors.append(f"{path}: context must be an object")
    else:
        for field in context:
            if field not in {"queries", "files", "skills"}:
                errors.append(f"{path}: unknown context field {field}")
        for file_path in context.get("files", []):
            if not (ROOT / file_path).exists():
                errors.append(f"{path}: context file does not exist: {file_path}")
    if not isinstance(workflow.get("steps"), list) or not workflow.get("steps"):
        errors.append(f"{path}: steps must be a non-empty array")
    else:
        step_ids = set()
        specs = provider_specs()
        for index, step in enumerate(workflow["steps"]):
            if not isinstance(step, dict):
                errors.append(f"{path}: step {index} must be an object")
                continue
            for field in ("id", "role", "prompt", "acceptance"):
                if field not in step:
                    errors.append(f"{path}: step {index} missing {field}")
            step_id = step.get("id")
            if step_id in step_ids:
                errors.append(f"{path}: duplicate step id: {step_id}")
            step_ids.add(step_id)
            unknown_step_fields = set(step) - {"id", "role", "prompt", "providers", "skills", "acceptance", "on_failure"}
            errors.extend(f"{path}: step {index}: unknown field {field}" for field in unknown_step_fields)
            if not isinstance(step.get("acceptance"), list) or not step.get("acceptance"):
                errors.append(f"{path}: step {index} acceptance must be non-empty")
            for provider in step.get("providers", []):
                if provider not in specs:
                    errors.append(f"{path}: unknown provider: {provider}")
            if step.get("on_failure", "stop") not in {"stop", "retry", "continue"}:
                errors.append(f"{path}: step {index}: invalid on_failure")
    limits = workflow.get("limits", {})
    for field in ("max_attempts", "timeout_seconds"):
        value = limits.get(field)
        if not isinstance(value, int) or isinstance(value, bool) or value < 1:
            errors.append(f"{path}: limits.{field} must be an integer")
    if "max_turns" in limits and (not isinstance(limits["max_turns"], int) or isinstance(limits["max_turns"], bool) or limits["max_turns"] < 1):
        errors.append(f"{path}: limits.max_turns must be a positive integer")
    if set(limits) - {"max_attempts", "timeout_seconds", "max_turns"}:
        errors.extend(f"{path}: unknown limits field {field}" for field in set(limits) - {"max_attempts", "timeout_seconds", "max_turns"})
    permission_values = {"filesystem": {"read-only", "workspace-write"}, "network": {"none", "allowlisted", "full"}, "git": {"read-only", "branch-write", "push"}, "github": {"none", "read-only", "write"}}
    for field in ("filesystem", "network", "git"):
        if field not in workflow.get("permissions", {}):
            errors.append(f"{path}: permissions.{field} is required")
    for field, values in permission_values.items():
        if field in workflow.get("permissions", {}) and workflow["permissions"][field] not in values:
            errors.append(f"{path}: invalid permissions.{field}")
    return errors


def doctor(args: argparse.Namespace) -> int:
    runner_data = load_json(RUNNERS)
    runner_specs = runner_data.get("providers", {})
    result = {
        provider: {
            "command": spec.get("command"),
            "path": shutil.which(spec.get("command", "")),
            "available": shutil.which(spec.get("command", "")) is not None,
            "headless": runner_specs.get(provider, {}).get("headless", []),
            "version": version_for(spec),
        }
        for provider, spec in runner_specs.items()
    }
    print(json.dumps({"runner": str(ROOT), "providers": result}, indent=2, sort_keys=True))
    return 0


def version_for(spec: dict[str, Any]) -> str | None:
    command = spec.get("command")
    if not command:
        return None
    try:
        result = subprocess.run(
            [command, *spec.get("version", ["--version"])],
            capture_output=True,
            text=True,
            timeout=8,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    output = (result.stdout or result.stderr).strip().splitlines()
    return output[0] if result.returncode == 0 and output else None


def workflow_validate(args: argparse.Namespace) -> int:
    errors = validate_workflow_file(Path(args.path).expanduser())
    if errors:
        print(json.dumps({"valid": False, "errors": errors}, indent=2))
        return 1
    print(json.dumps({"valid": True, "path": args.path}))
    return 0


def workflow_plan(args: argparse.Namespace) -> int:
    path = Path(args.path).expanduser()
    errors = validate_workflow_file(path)
    if errors:
        print(json.dumps({"valid": False, "errors": errors}, indent=2))
        return 1
    workflow = load_json(path)
    runner_specs = load_json(RUNNERS).get("providers", {})
    policy = load_json(POLICY)
    policy_values = {"filesystem": ["read-only", "workspace-write"], "network": ["none", "allowlisted", "full"], "git": ["read-only", "branch-write", "push"], "github": ["none", "read-only", "write"]}
    permission_errors = []
    for field, values in policy_values.items():
        requested = workflow["permissions"].get(field, "none")
        allowed = policy.get(field, values[0])
        if values.index(requested) > values.index(allowed):
            permission_errors.append(f"permissions.{field}={requested} exceeds policy {allowed}")
    if permission_errors:
        print(json.dumps({"valid": False, "errors": permission_errors, "policy": policy["id"]}, indent=2))
        return 1
    specs = provider_specs()
    availability = {provider: shutil.which(spec.get("command", "")) is not None for provider, spec in specs.items()}
    steps = []
    for step in workflow["steps"]:
        candidates = step.get("providers") or list(specs)
        available = [provider for provider in candidates if availability.get(provider, False)]
        steps.append({
            "id": step["id"],
            "role": step["role"],
            "candidates": candidates,
            "available": available,
            "selected": available[0] if available else None,
            "acceptance": step["acceptance"],
            "status": "ready" if available else "unavailable",
            "runner": runner_specs.get(available[0], {}) if available else None,
        })
    unavailable_steps = [step["id"] for step in steps if step["status"] == "unavailable"]
    plan = {
        "workflow_id": workflow["id"],
        "run_id": f"{workflow['id']}-{uuid.uuid4().hex[:12]}",
        "status": "planned" if not unavailable_steps else "unavailable",
        "objective": workflow["objective"],
        "context": workflow.get("context", {}),
        "limits": workflow["limits"],
        "permissions": workflow["permissions"],
        "policy": policy["id"],
        "steps": steps,
        "available_providers": [provider for provider, available in availability.items() if available],
        "unavailable_steps": unavailable_steps,
        "execution": "dry-run; no provider process was started",
    }
    print(json.dumps(plan, indent=2, sort_keys=True))
    return 0 if not unavailable_steps else 1


def workflow_prompt(workflow: dict[str, Any], step: dict[str, Any], run_id: str) -> str:
    context = workflow.get("context", {})
    return "\n".join([
        f"Workflow: {workflow['id']}",
        f"Run ID: {run_id}",
        f"Objective: {workflow['objective']}",
        f"Knowledge queries: {json.dumps(context.get('queries', []))}",
        f"Context files: {json.dumps(context.get('files', []))}",
        f"Role: {step['role']}",
        f"Task: {step['prompt']}",
        "Acceptance criteria:",
        *[f"- {criterion}" for criterion in step["acceptance"]],
        "Record the provider session ID and cite repository/source references in the result.",
    ])


def provider_command(provider: str, spec: dict[str, Any], prompt: str) -> tuple[list[str], str | None]:
    command = [spec["command"], *spec.get("headless", [])]
    if provider == "codex":
        return [*command, "--cd", str(ROOT), "-"], prompt
    if provider == "vibe":
        return [spec["command"], "--output", "json", "--prompt", prompt], None
    return [*command, prompt], None


def extract_session_id(output: str) -> str | None:
    for line in output.splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            for key in ("session_id", "sessionId", "sessionID", "thread_id", "threadId"):
                candidate = value.get(key)
                if isinstance(candidate, str) and candidate:
                    return candidate
    match = re.search(r"\b[0-9a-f]{8}-[0-9a-f-]{27,}\b", output, re.I)
    return match.group(0) if match else None


def append_session_record(provider: str, session_id: str, run_id: str, summary: str) -> None:
    record = {
        "session_id": f"{provider}:{session_id}",
        "provider": provider,
        "harness": provider,
        "started_at": now(),
        "status": "completed",
        "issues": [],
        "prs": [],
        "sources": [],
        "commits": [],
        "summary": summary,
        "run_id": run_id,
    }
    INDEX.parent.mkdir(parents=True, exist_ok=True)
    with INDEX.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(record, sort_keys=True) + "\n")


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def append_ledger_event(run_id: str, workflow_id: str, provider: str, status: str) -> str:
    ledger = ROOT / ".agents/ledger.md"
    event = f"| {datetime.now(timezone.utc).date().isoformat()} | Run `{run_id}` for workflow `{workflow_id}` used `{provider}` and ended with `{status}`; result artifact is `.agents/state/runs/{run_id}/result.json`. |\n"
    content = ledger.read_text(encoding="utf-8")
    marker = "|---|---|\n"
    if marker not in content:
        raise ValueError("ledger table header not found")
    updated = content.replace(marker, marker + event, 1)
    temporary = ledger.with_suffix(".md.tmp")
    temporary.write_text(updated, encoding="utf-8")
    temporary.replace(ledger)
    return f".agents/ledger.md#{run_id}"


def workflow_run(args: argparse.Namespace) -> int:
    path = Path(args.path).expanduser()
    errors = validate_workflow_file(path)
    if errors:
        print(json.dumps({"valid": False, "errors": errors}, indent=2))
        return 1
    workflow = load_json(path)
    specs = provider_specs()
    provider = args.provider
    if provider == "auto":
        candidates = [name for name, spec in specs.items() if shutil.which(spec.get("command", ""))]
        provider = candidates[0] if candidates else None
    if provider not in specs or shutil.which(specs.get(provider, {}).get("command", "")) is None:
        print(json.dumps({"status": "unavailable", "provider": provider}, indent=2))
        return 1
    run_id = f"{workflow['id']}-{uuid.uuid4().hex[:12]}"
    database = Path(args.database).expanduser()
    run_dir = database.parent / "runs" / run_id
    result: dict[str, Any] = {
        "workflow_id": workflow["id"], "run_id": run_id, "status": "planned",
        "started_at": now(), "steps": [], "session_ids": [], "artifacts": [], "ledger_refs": [],
        "provider": provider,
    }
    if not args.execute:
        write_json(run_dir / "result.json", result)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    result["status"] = "running"
    write_json(run_dir / "result.json", result)
    spec = specs[provider]
    if workflow["permissions"].get("filesystem") == "read-only" and not spec.get("enforces_read_only", False):
        result["status"] = "unavailable"
        result["reason"] = f"provider adapter {provider} has not verified read-only enforcement"
        write_json(run_dir / "result.json", result)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 1
    for step in workflow["steps"]:
        prompt = workflow_prompt(workflow, step, run_id)
        command, stdin = provider_command(provider, spec, prompt)
        step_id = step["id"]
        try:
            completed = subprocess.run(
                command, input=stdin, capture_output=True, text=True,
                cwd=ROOT, timeout=workflow["limits"]["timeout_seconds"], check=False,
            )
            output = (completed.stdout or "") + (completed.stderr or "")
            artifact = run_dir / f"{step_id}.output"
            artifact.parent.mkdir(parents=True, exist_ok=True)
            artifact.write_text(output, encoding="utf-8")
            session_id = extract_session_id(output)
            step_result = {
                "id": step_id,
                "status": "succeeded" if completed.returncode == 0 else "failed",
                "acceptance_results": [{"criterion": criterion, "status": "pending"} for criterion in step["acceptance"]],
                "session_id": session_id,
                "artifact": str(artifact.relative_to(ROOT)),
            }
            result["steps"].append(step_result)
            result["artifacts"].append(str(artifact.relative_to(ROOT)))
            if session_id:
                namespaced = f"{provider}:{session_id}"
                result["session_ids"].append(namespaced)
                append_session_record(provider, session_id, run_id, f"Workflow {workflow['id']} step {step_id}")
            if completed.returncode != 0:
                result["status"] = "failed"
                break
        except (OSError, subprocess.TimeoutExpired) as error:
            result["steps"].append({"id": step_id, "status": "failed", "acceptance_results": [{"status": "error", "detail": str(error)}]})
            result["status"] = "failed"
            break
        write_json(run_dir / "result.json", result)
    if result["status"] == "running":
        result["status"] = "awaiting_acceptance"
    result["completed_at"] = now()
    result["ledger_refs"].append(append_ledger_event(run_id, workflow["id"], provider, result["status"]))
    write_json(run_dir / "result.json", result)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "succeeded" else 1


def policy_compile(args: argparse.Namespace) -> int:
    policy = load_json(Path(args.path).expanduser())
    required = ("schema_version", "id", "filesystem", "network", "git", "github")
    errors = [f"missing {field}" for field in required if field not in policy]
    values = {"filesystem": {"read-only", "workspace-write"}, "network": {"none", "allowlisted", "full"}, "git": {"read-only", "branch-write", "push"}, "github": {"none", "read-only", "write"}}
    for field, allowed in values.items():
        if field in policy and policy[field] not in allowed:
            errors.append(f"invalid {field}: {policy[field]}")
    if errors:
        print(json.dumps({"valid": False, "errors": errors}, indent=2))
        return 1
    projection = {
        "provider": args.provider,
        "policy_id": policy["id"],
        "deny_by_default": True,
        "filesystem": policy["filesystem"],
        "network": policy["network"],
        "git": policy["git"],
        "github": policy["github"],
        "allow_hosts": policy.get("allow_hosts", []),
        "require_session_id": policy.get("require_session_id", True),
        "require_ledger_event": policy.get("require_ledger_event", True),
        "require_acceptance": policy.get("require_acceptance", True),
        "require_draft_pr": policy.get("require_draft_pr", True),
        "enforced": False,
        "native_mapping": "adapter-owned; fail closed when unsupported",
    }
    print(json.dumps(projection, indent=2, sort_keys=True))
    return 0


def maintain(args: argparse.Namespace) -> int:
    workflow_paths = sorted((ROOT / ".agents/workflows").glob("*.json"))
    errors = []
    for path in workflow_paths:
        if path.name in {"schema.json", "result.schema.json"}:
            continue
        errors.extend(validate_workflow_file(path))
    database = Path(args.database).expanduser()
    rebuild(argparse.Namespace(database=str(database)), emit=False)
    result = {
        "status": "healthy" if not errors else "failed",
        "knowledge": str(DATABASE),
        "workflows": [str(path.relative_to(ROOT)) for path in workflow_paths if "schema" not in path.name],
        "errors": errors,
    }
    runs = database.parent / "runs"
    runs.mkdir(parents=True, exist_ok=True)
    temporary = runs / ".last-maintenance.json.tmp"
    temporary.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    temporary.replace(runs / "last-maintenance.json")
    print(json.dumps(result, indent=2))
    return 0 if not errors else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", default=str(DATABASE))
    commands = parser.add_subparsers(dest="command", required=True)
    knowledge = commands.add_parser("knowledge")
    knowledge_commands = knowledge.add_subparsers(dest="knowledge_command", required=True)
    knowledge_commands.add_parser("rebuild")
    query_parser = commands.add_parser("query")
    query_parser.add_argument("term")
    query_parser.add_argument("--limit", type=int, default=10)
    context_parser = commands.add_parser("context")
    context_parser.add_argument("term")
    context_parser.add_argument("--limit", type=int, default=10)
    commands.add_parser("doctor")
    commands.add_parser("maintain")
    commands.add_parser("heal")
    workflow = commands.add_parser("workflow")
    workflow_commands = workflow.add_subparsers(dest="workflow_command", required=True)
    validate = workflow_commands.add_parser("validate")
    validate.add_argument("path")
    plan = workflow_commands.add_parser("plan")
    plan.add_argument("path")
    run = workflow_commands.add_parser("run")
    run.add_argument("path")
    run.add_argument("--provider", default="auto")
    run.add_argument("--execute", action="store_true")
    policy = commands.add_parser("policy")
    policy_commands = policy.add_subparsers(dest="policy_command", required=True)
    compile_policy = policy_commands.add_parser("compile")
    compile_policy.add_argument("--provider", required=True)
    compile_policy.add_argument("--path", default=str(POLICY))
    sessions = commands.add_parser("sessions")
    sessions.add_argument("--index", default=str(INDEX))
    session_commands = sessions.add_subparsers(dest="session_command", required=True)
    listing = session_commands.add_parser("list")
    listing.add_argument("--provider")
    register = session_commands.add_parser("register")
    register.add_argument("--session-id", required=True)
    register.add_argument("--provider", required=True)
    register.add_argument("--harness", required=True)
    register.add_argument("--status", default="active")
    register.add_argument("--started-at")
    register.add_argument("--issue", action="append", default=[])
    register.add_argument("--pr", action="append", default=[])
    register.add_argument("--source", action="append", default=[])
    register.add_argument("--commit", action="append", default=[])
    register.add_argument("--transcript")
    register.add_argument("--summary", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "knowledge":
        return rebuild(args)
    if args.command == "query":
        return query(args)
    if args.command == "context":
        return context(args)
    if args.command == "doctor":
        return doctor(args)
    if args.command in ("maintain", "heal"):
        return maintain(args)
    if args.command == "workflow" and args.workflow_command == "validate":
        return workflow_validate(args)
    if args.command == "workflow" and args.workflow_command == "plan":
        return workflow_plan(args)
    if args.command == "workflow" and args.workflow_command == "run":
        return workflow_run(args)
    if args.command == "policy" and args.policy_command == "compile":
        return policy_compile(args)
    if args.command == "sessions" and args.session_command == "list":
        return session_list(args)
    if args.command == "sessions" and args.session_command == "register":
        return session_register(args)
    raise ValueError("unsupported command")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, sqlite3.Error) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(2)
