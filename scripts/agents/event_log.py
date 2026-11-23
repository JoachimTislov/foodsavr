"""Per-event repository logs (#397).

Every new ledger or session record is its own one-line `.jsonl` file under
`.agents/events/<YYYY>/<MM>/`, so no two branches ever edit the same file and
GitHub never reports a log-only conflict. The legacy aggregate files
(`.agents/ledger.jsonl`, `.agents/sessions/index.jsonl`) are frozen: writers
never append to them, readers keep reading them before the events.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import secrets
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

EVENTS_REL = Path(".agents/events")
LEGACY_LEDGER_REL = Path(".agents/ledger.jsonl")
LEGACY_SESSIONS_REL = Path(".agents/sessions/index.jsonl")
STREAMS = ("ledger", "sessions")
NAME_RE = re.compile(r"^(?P<time>\d{8}T\d{12}Z)-(?P<slug>[a-z0-9]+(?:-[a-z0-9]+)*)-(?P<rand>[0-9a-f]{6})\.jsonl$")
SLUG_MAX = 48


def session_slug(session_id: str | None) -> str:
    """Filesystem-safe, lowercase slug of a session id (`human` when there is none)."""
    slug = re.sub(r"[^a-z0-9]+", "-", str(session_id or "").lower()).strip("-")[:SLUG_MAX].strip("-")
    return slug or "human"


def event_path(directory: Path, moment: datetime, session_id: str | None, rand: str | None = None) -> Path:
    moment = moment.astimezone(timezone.utc)
    stamp = moment.strftime("%Y%m%dT%H%M%S") + f"{moment.microsecond:06d}Z"
    name = f"{stamp}-{session_slug(session_id)}-{rand or secrets.token_hex(3)}.jsonl"
    return directory / f"{moment:%Y}" / f"{moment:%m}" / name


def write_event(directory: Path, stream: str, record: dict[str, Any], session_id: str | None = None,
                moment: datetime | None = None) -> Path:
    """Write `record` (plus its `stream`) as a new single-line event file; never overwrites."""
    if stream not in STREAMS:
        raise ValueError(f"unknown log stream: {stream}")
    line = json.dumps({**record, "stream": stream}, sort_keys=True, allow_nan=False) + "\n"
    moment = moment or datetime.now(timezone.utc)
    for _ in range(8):
        path = event_path(directory, moment, session_id)
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name("." + path.name + ".tmp")
        temporary.write_text(line, encoding="utf-8")
        try:
            os.link(temporary, path)  # fails instead of clobbering on a name collision
        except FileExistsError:
            continue
        finally:
            temporary.unlink(missing_ok=True)
        return path
    raise OSError(f"could not allocate a unique event file under {directory}")


def event_files(directory: Path) -> list[Path]:
    """Event files in chronological order (names start with a sortable UTC timestamp)."""
    if not directory.is_dir():
        return []
    return sorted((p for p in directory.rglob("*.jsonl") if p.is_file() and not p.name.startswith(".")),
                  key=lambda p: p.name)


def read_events(directory: Path, stream: str | None = None) -> list[dict[str, Any]]:
    """Records of the event files, oldest first; unreadable files are skipped (check_logs reports them)."""
    rows = []
    for path in event_files(directory):
        try:
            value = json.loads(path.read_text(encoding="utf-8").splitlines()[0])
        except (OSError, ValueError, IndexError):
            continue
        if isinstance(value, dict) and (stream is None or value.get("stream") == stream):
            rows.append(value)
    return rows


def directory_digest(directory: Path) -> str:
    """Cheap fingerprint of an events directory: file names and sizes (event files are immutable)."""
    files = event_files(directory)
    digest = hashlib.sha256()
    for path in files:
        digest.update(f"{path.relative_to(directory).as_posix()}:{path.stat().st_size}\n".encode())
    return digest.hexdigest() if files else ""


def is_event_path(path: Path) -> bool:
    return path.parts[:2] == EVENTS_REL.parts


def event_errors(name: str, text: str, path: Path) -> list[str]:
    """Format and required-field errors of one event file (`path` is repository-relative)."""
    errors = []
    match = NAME_RE.match(path.name)
    if not match:
        return [f"{name}: event file name must be <YYYYMMDDTHHMMSSffffffZ>-<session slug>-<6 hex>.jsonl"]
    if path.parent.parts[-2:] != (match["time"][:4], match["time"][4:6]) or path.parts[:2] != EVENTS_REL.parts:
        errors.append(f"{name}: event files live in {EVENTS_REL}/<YYYY>/<MM>/ matching their timestamp")
    lines = text.splitlines()
    if len(lines) != 1 or not text.endswith("\n"):
        return [*errors, f"{name}: an event file holds exactly one JSON object line with a final newline"]
    try:
        record = json.loads(lines[0], parse_constant=_reject_constant)
    except ValueError as error:
        return [*errors, f"{name}:1: {error}"]
    if not isinstance(record, dict):
        return [*errors, f"{name}:1: record must be an object"]
    stream = record.get("stream")
    if stream not in STREAMS:
        return [*errors, f"{name}: `stream` must be one of {', '.join(STREAMS)}"]
    required = ("timestamp", "session_id") if stream == "ledger" else ("session_id", "provider", "harness", "started_at", "status", "summary")
    errors.extend(f"{name}: {stream} event needs `{field}`" for field in required if not record.get(field))
    if stream == "ledger" and not (record.get("event") or record.get("type")):
        errors.append(f"{name}: ledger event needs `event` or `type`")
    return errors


def _reject_constant(value: str) -> None:
    raise ValueError(f"non-JSON number: {value}")
