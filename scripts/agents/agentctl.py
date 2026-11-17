#!/usr/bin/env python3
"""Agent-native repository context, session, and knowledge catalog CLI."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / ".agents/sessions/index.jsonl"
SCHEMA = ROOT / ".agents/knowledge/schema.sql"
DATABASE = ROOT / ".agents/state/knowledge.sqlite3"
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


def rebuild(args: argparse.Namespace) -> int:
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
