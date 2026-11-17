#!/usr/bin/env python3
"""Agent-native repository context, session, and knowledge catalog CLI."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sqlite3
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / ".agents/sessions/index.jsonl"
SCHEMA = ROOT / ".agents/knowledge/schema.sql"
DATABASE = ROOT / ".agents/state/knowledge.sqlite3"
RUNS = ROOT / ".agents/state/runs"
RUNNERS = ROOT / ".agents/runners/providers.json"
POLICY = ROOT / ".agents/policies/default.json"
TEXT_SUFFIXES = {".md", ".markdown", ".yaml", ".yml", ".json", ".toml"}
EXCLUDED_PARTS = {".git", ".dart_tool", "build", "research", "state"}
URL_RE = re.compile(r"https?://[^\s)\]>]+")
ISSUE_RE = re.compile(r"(?<![\w])#\d+")
SHA_RE = re.compile(r"(?<![0-9a-f])[0-9a-f]{7,40}(?![0-9a-f])", re.I)


def now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def records(index: Path = INDEX) -> list[dict[str, Any]]:
    if not index.exists():
        return []
    result = []
    for number, line in enumerate(index.read_text().splitlines(), 1):
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
    connection.executescript(SCHEMA.read_text())
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
                if EXCLUDED_PARTS.intersection(path.parts):
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


def query(args: argparse.Namespace) -> int:
    connection = connect(Path(args.database).expanduser())
    rows = connection.execute(
        "SELECT title, path, snippet(document_search, 1, '[', ']', '…', 24) AS snippet, bm25(document_search) AS rank "
        "FROM document_search WHERE document_search MATCH ? ORDER BY rank LIMIT ?",
        (search_phrase(args.term), args.limit),
    ).fetchall()
    print(json.dumps([dict(row) for row in rows], indent=2))
    return 0


def context(args: argparse.Namespace) -> int:
    connection = connect(Path(args.database).expanduser())
    docs = connection.execute(
        "SELECT title, path, snippet(document_search, 1, '[', ']', '…', 20) AS snippet "
        "FROM document_search WHERE document_search MATCH ? ORDER BY bm25(document_search) LIMIT ?",
        (search_phrase(args.term), args.limit),
    ).fetchall()
    sessions = connection.execute(
        "SELECT session_id, provider, harness, status, summary FROM sessions "
        "WHERE session_id LIKE ? OR summary LIKE ? ORDER BY started_at DESC LIMIT ?",
        (f"%{args.term}%", f"%{args.term}%", args.limit),
    ).fetchall()
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


PROVIDERS = {
    "codex": "codex",
    "claude": "claude",
    "opencode": "opencode",
    "gemini": "gemini",
    "vibe": "vibe",
    "copilot": "copilot",
}


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
    for field in ("schema_version", "id", "objective", "steps", "limits", "permissions"):
        if field not in workflow:
            errors.append(f"{path}: missing {field}")
    if workflow.get("schema_version") != 1:
        errors.append(f"{path}: schema_version must be 1")
    if not isinstance(workflow.get("steps"), list) or not workflow.get("steps"):
        errors.append(f"{path}: steps must be a non-empty array")
    else:
        for index, step in enumerate(workflow["steps"]):
            if not isinstance(step, dict):
                errors.append(f"{path}: step {index} must be an object")
                continue
            for field in ("id", "role", "prompt", "acceptance"):
                if field not in step:
                    errors.append(f"{path}: step {index} missing {field}")
            if not isinstance(step.get("acceptance"), list) or not step.get("acceptance"):
                errors.append(f"{path}: step {index} acceptance must be non-empty")
    for field in ("max_attempts", "timeout_seconds"):
        if not isinstance(workflow.get("limits", {}).get(field), int):
            errors.append(f"{path}: limits.{field} must be an integer")
    for field in ("filesystem", "network", "git"):
        if field not in workflow.get("permissions", {}):
            errors.append(f"{path}: permissions.{field} is required")
    return errors


def doctor(args: argparse.Namespace) -> int:
    runner_data = load_json(RUNNERS)
    runner_specs = runner_data.get("providers", {})
    result = {
        provider: {
            "command": command,
            "path": shutil.which(command),
            "available": shutil.which(command) is not None,
            "headless": runner_specs.get(provider, {}).get("headless", []),
        }
        for provider, command in PROVIDERS.items()
    }
    print(json.dumps({"runner": str(ROOT), "providers": result}, indent=2, sort_keys=True))
    return 0


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
    availability = {provider: shutil.which(command) is not None for provider, command in PROVIDERS.items()}
    steps = []
    for step in workflow["steps"]:
        candidates = step.get("providers") or list(PROVIDERS)
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
    plan = {
        "workflow_id": workflow["id"],
        "run_id": f"{workflow['id']}-{uuid.uuid4().hex[:12]}",
        "status": "planned",
        "objective": workflow["objective"],
        "context": workflow.get("context", {}),
        "limits": workflow["limits"],
        "permissions": workflow["permissions"],
        "steps": steps,
        "available_providers": [provider for provider, available in availability.items() if available],
        "execution": "dry-run; no provider process was started",
    }
    print(json.dumps(plan, indent=2, sort_keys=True))
    return 0


def policy_compile(args: argparse.Namespace) -> int:
    policy = load_json(Path(args.path).expanduser())
    required = ("schema_version", "id", "filesystem", "network", "git", "github")
    errors = [f"missing {field}" for field in required if field not in policy]
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
        "native_mapping": "adapter-owned; fail closed when unsupported",
    }
    print(json.dumps(projection, indent=2, sort_keys=True))
    return 0


def maintain(args: argparse.Namespace) -> int:
    workflow_paths = sorted((ROOT / ".agents/workflows").glob("*.json"))
    errors = []
    for path in workflow_paths:
        if path.name.endswith("schema.json") or path.name == "result.schema.json":
            continue
        errors.extend(validate_workflow_file(path))
    rebuild(argparse.Namespace(database=str(DATABASE)), emit=False)
    result = {
        "status": "healthy" if not errors else "failed",
        "knowledge": str(DATABASE),
        "workflows": [str(path.relative_to(ROOT)) for path in workflow_paths if "schema" not in path.name],
        "errors": errors,
    }
    RUNS.mkdir(parents=True, exist_ok=True)
    (RUNS / "last-maintenance.json").write_text(json.dumps(result, indent=2) + "\n")
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
