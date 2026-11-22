#!/usr/bin/env python3
"""Assert the JSONL format of repository-maintained logs.

Also enforces traceability (#271): ledger events at or after
`traceability.CUTOFF` carry a `session_id` that resolves in the session index
(or is the human marker); older lines are grandfathered and never edited.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import traceability as tr  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
INDEX = Path(".agents/sessions/index.jsonl")
# Session IDs minted by automation need no index record.
AUTOMATION_PREFIXES = ("github-actions:", "agentctl:")


def reject_constant(value: str) -> None:
    raise ValueError(f"non-JSON number: {value}")


def validate(path: Path) -> None:
    """Require UTF-8, newline-terminated JSON objects, and no blank records."""
    content = path.read_text(encoding="utf-8")
    if content and not content.endswith("\n"):
        raise ValueError(f"{path}: missing final newline")
    for number, line in enumerate(content.splitlines(), 1):
        try:
            record = json.loads(line, parse_constant=reject_constant)
            if not isinstance(record, dict):
                raise ValueError("record must be an object")
        except ValueError as error:
            raise ValueError(f"{path}:{number}: {error}") from error


def traceability_errors(name: str, records: list[dict], sessions: list[dict], is_ledger: bool) -> list[str]:
    """Require owners on new records. Records before the cutoff are grandfathered."""
    errors = []
    for number, record in enumerate(records, 1):
        if tr.is_legacy(record):
            continue
        where = f"{name}:{number}"
        if is_ledger:
            if tr.parse_time(record.get("timestamp")) is None:
                errors.append(f"{where}: ledger event needs an ISO `timestamp`")
            session_id = record.get("session_id")
            if not isinstance(session_id, str) or not session_id:
                errors.append(f"{where}: ledger event needs `session_id` (use `agentctl log`)")
            elif session_id == tr.HUMAN or session_id.startswith(AUTOMATION_PREFIXES):
                continue
            elif not tr.SESSION_RE.match(session_id):
                errors.append(f"{where}: invalid session_id {session_id!r}; expected <harness>:<id>")
            elif tr.find_record(sessions, session_id) is None:
                errors.append(f"{where}: session_id {session_id!r} is not registered in {INDEX}")
        elif not tr.SESSION_RE.match(str(record.get("session_id", ""))):
            errors.append(f"{where}: new session records need a canonical <harness>:<id> session_id")
        if not is_ledger and "transcript" in record and not str(record["transcript"]).startswith("gs://"):
            errors.append(f"{where}: `transcript` must be an archive gs:// URI (local transcript paths are never committed)")
    return errors


def check(root: Path, paths: list[str]) -> list[str]:
    errors = []
    sessions: list[dict] | None = None
    for name in paths:
        path = Path(name)
        is_ledger = path.stem.endswith("ledger") and path.suffix == ".jsonl" and path.parts[0] == ".agents"
        is_index = path == INDEX
        is_log = (
            path.parts[0] in {"log", "logs"}
            or path.suffix == ".log"
            or path.stem.endswith("ledger")
            or (path.parent == Path(".agents/sessions") and path.stem == "index")
        )
        if is_log and path.suffix != ".jsonl":
            errors.append(f"{name}: repository logs must use .jsonl")
        elif path.suffix == ".jsonl":
            try:
                validate(root / path)
            except (ValueError, OSError) as error:
                errors.append(str(error))
                continue
            if is_ledger or is_index:
                if sessions is None:
                    sessions = tr.fold_records(tr.read_jsonl(root / INDEX))  # duplicate lines are legal (merge=union)
                rows = tr.read_jsonl(root / path)
                errors.extend(traceability_errors(name, tr.fold_records(rows) if is_index else rows, sessions, is_ledger))
    return errors


def main() -> int:
    paths = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=ROOT,
    ).decode().rstrip("\0").split("\0")
    errors = check(ROOT, paths)
    for error in errors:
        print(error)
    if not errors:
        print("Repository logs: JSONL OK")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
