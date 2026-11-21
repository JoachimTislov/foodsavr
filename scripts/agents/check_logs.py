#!/usr/bin/env python3
"""Assert the JSONL format of repository-maintained logs."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


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


def check(root: Path, paths: list[str]) -> list[str]:
    errors = []
    for name in paths:
        path = Path(name)
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
