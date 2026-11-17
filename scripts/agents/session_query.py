#!/usr/bin/env python3
"""Register and query provider-agnostic agent session metadata.

Session transcripts remain outside the repository. This index stores only
correlation metadata and optional local transcript paths.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INDEX = ROOT / ".agents/sessions/index.jsonl"
SEARCH_FILES = (ROOT / ".agents/ledger.md", ROOT / "TODO.md", ROOT / "README.md")


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def read_records(index: Path) -> list[dict[str, Any]]:
    if not index.exists():
        return []
    records: list[dict[str, Any]] = []
    for line_number, line in enumerate(index.read_text().splitlines(), 1):
        if not line.strip():
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(f"{index}:{line_number}: invalid JSON: {error}") from error
        if not isinstance(record, dict):
            raise ValueError(f"{index}:{line_number}: record must be an object")
        records.append(record)
    return records


def write_record(index: Path, record: dict[str, Any]) -> None:
    index.parent.mkdir(parents=True, exist_ok=True)
    with index.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(record, sort_keys=True) + "\n")


def values(record: dict[str, Any]) -> Iterable[str]:
    for value in record.values():
        if isinstance(value, list):
            yield from (str(item) for item in value)
        elif value is not None:
            yield str(value)


def output(records: list[dict[str, Any]], as_json: bool) -> None:
    if as_json:
        print(json.dumps(records, indent=2, sort_keys=True))
        return
    for record in records:
        issues = ",".join(record.get("issues", [])) or "-"
        prs = ",".join(record.get("prs", [])) or "-"
        print(
            f"{record.get('session_id', '?')}\t"
            f"{record.get('provider', '?')}/{record.get('harness', '?')}\t"
            f"{record.get('status', '?')}\tissues={issues}\tprs={prs}\t"
            f"{record.get('summary', '')}"
        )


def search_text(term: str) -> list[dict[str, str]]:
    needle = term.casefold()
    matches: list[dict[str, str]] = []
    for path in SEARCH_FILES:
        if not path.exists():
            continue
        for line_number, line in enumerate(path.read_text().splitlines(), 1):
            if needle in line.casefold():
                matches.append({"file": str(path.relative_to(ROOT)), "line": str(line_number), "text": line})
    return matches


def transcript_matches(records: list[dict[str, Any]], term: str) -> list[dict[str, str]]:
    needle = term.casefold()
    matches: list[dict[str, str]] = []
    for record in records:
        transcript = record.get("transcript")
        if not transcript:
            continue
        path = Path(transcript).expanduser()
        if not path.is_absolute():
            path = ROOT / path
        if not path.exists():
            continue
        for line_number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
            if needle in line.casefold():
                matches.append({
                    "session_id": str(record.get("session_id", "?")),
                    "file": str(path),
                    "line": str(line_number),
                    "text": line,
                })
    return matches


def command_register(args: argparse.Namespace) -> int:
    index = Path(args.index).expanduser()
    records = read_records(index)
    if any(record.get("session_id") == args.session_id for record in records):
        raise ValueError(f"session already registered: {args.session_id}")
    record = {
        "session_id": args.session_id,
        "provider": args.provider,
        "harness": args.harness,
        "started_at": args.started_at or utc_now(),
        "status": args.status,
        "issues": args.issue,
        "prs": args.pr,
        "sources": args.source,
        "commits": args.commit,
        "summary": args.summary,
    }
    if args.transcript:
        record["transcript"] = args.transcript
    write_record(index, record)
    output([record], args.json)
    return 0


def command_list(args: argparse.Namespace) -> int:
    records = read_records(Path(args.index).expanduser())
    if args.provider:
        records = [record for record in records if record.get("provider") == args.provider]
    if args.issue:
        records = [record for record in records if args.issue in record.get("issues", [])]
    if args.pr:
        records = [record for record in records if args.pr in record.get("prs", [])]
    output(records, args.json)
    return 0


def command_show(args: argparse.Namespace) -> int:
    records = [
        record
        for record in read_records(Path(args.index).expanduser())
        if record.get("session_id") == args.session_id
    ]
    if not records:
        raise ValueError(f"session not found: {args.session_id}")
    output(records, True)
    return 0


def command_search(args: argparse.Namespace) -> int:
    records = read_records(Path(args.index).expanduser())
    matching_records = [
        record for record in records if args.term.casefold() in " ".join(values(record)).casefold()
    ]
    result = {
        "sessions": matching_records,
        "repository": search_text(args.term),
        "transcripts": transcript_matches(records, args.term),
    }
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        output(matching_records, False)
        for group in (result["repository"], result["transcripts"]):
            for match in group:
                prefix = match.get("session_id", match["file"])
                print(f"{prefix}:{match['line']}: {match['text']}")
    return 0


def command_validate(args: argparse.Namespace) -> int:
    records = read_records(Path(args.index).expanduser())
    errors: list[str] = []
    seen: set[str] = set()
    required = ("session_id", "provider", "harness", "started_at", "status", "summary")
    for record in records:
        session_id = record.get("session_id")
        if not isinstance(session_id, str) or not session_id:
            errors.append("record has no session_id")
        elif session_id in seen:
            errors.append(f"duplicate session_id: {session_id}")
        else:
            seen.add(session_id)
        for field in required:
            if field not in record:
                errors.append(f"{session_id or '?'} missing {field}")
        for field in ("issues", "prs", "sources", "commits"):
            if not isinstance(record.get(field, []), list):
                errors.append(f"{session_id or '?'} field {field} must be a list")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"valid: {len(records)} session record(s)")
    return 0


def parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--index", default=argparse.SUPPRESS, help="JSONL session index")
    common.add_argument("--json", action="store_true", default=argparse.SUPPRESS, help="emit JSON")
    root = argparse.ArgumentParser(description=__doc__, parents=[common])
    commands = root.add_subparsers(dest="command", required=True)

    register = commands.add_parser("register", parents=[common])
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

    listing = commands.add_parser("list", parents=[common])
    listing.add_argument("--provider")
    listing.add_argument("--issue")
    listing.add_argument("--pr")

    show = commands.add_parser("show", parents=[common])
    show.add_argument("session_id")

    search = commands.add_parser("search", parents=[common])
    search.add_argument("term")

    commands.add_parser("validate", parents=[common])
    return root


def main() -> int:
    args = parser().parse_args()
    if not hasattr(args, "index"):
        args.index = str(DEFAULT_INDEX)
    if not hasattr(args, "json"):
        args.json = False
    try:
        return {
            "register": command_register,
            "list": command_list,
            "show": command_show,
            "search": command_search,
            "validate": command_validate,
        }[args.command](args)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
