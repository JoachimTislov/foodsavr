#!/usr/bin/env python3
"""Git-derived facts for `trace`: rebase equivalence, direct and projection-backed lookups.

Rebase merges rewrite SHAs, so logs recorded before the merge name commits that
no longer exist on `main`. `Equivalence` maps a commit back to those recorded
SHAs by patch-id (when the old object still exists locally) and by author
date + email + subject (rebase preserves both). Fingerprints of immutable
objects are cached on disk so repeated traces stay fast.
"""

from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import subprocess
import time
from pathlib import Path
from typing import Any

import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import traceability as tr  # noqa: E402

LOG_FORMAT = "%H%x1f%an%x1f%ae%x1f%aI%x1f%s%x1f%B%x1e"
EQUIVALENCE_TARGET_LIMIT = 300


def _git(root: Path, *args: str, stdin: str | None = None, timeout: int = 30) -> str | None:
    try:
        result = subprocess.run(["git", "-C", str(root), *args], input=stdin, capture_output=True, text=True,
                                timeout=timeout, stdin=None if stdin is not None else subprocess.DEVNULL, check=False)
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout if result.returncode == 0 else None


class Equivalence:
    """Map a commit to recorded (index/ledger) SHAs that a rebase rewrote."""

    def __init__(self, root: Path, sessions: list[dict[str, Any]], ledger: list[dict[str, Any]],
                 cache_path: Path | None = None, deadline: float | None = None) -> None:
        self.root, self.cache_path, self.deadline = root, cache_path, deadline
        self.recorded = tr.unique([str(c) for row in (*sessions, *ledger) for c in tr.row_shas(row) if tr.HEX_RE.match(str(c))])
        self._candidates: list[dict[str, Any]] | None = None
        self._patch: dict[str, str] = {}
        self._dirty = False
        if cache_path and cache_path.is_file():
            try:
                data = json.loads(cache_path.read_text(encoding="utf-8"))
                self._patch = {k: v for k, v in data.get("patch", {}).items() if isinstance(v, str)}
            except (OSError, ValueError):
                self._patch = {}

    def candidates(self) -> list[dict[str, Any]]:
        """Recorded SHAs whose objects still exist locally, with their match keys."""
        if self._candidates is not None:
            return self._candidates
        self._candidates = []
        if not self.recorded:
            return self._candidates
        checked = _git(self.root, "cat-file", "--batch-check", stdin="".join(f"{c}^{{commit}}\n" for c in self.recorded))
        resolved: list[tuple[str, str]] = []
        for recorded, line in zip(self.recorded, (checked or "").splitlines()):
            parts = line.split()
            if len(parts) == 3 and parts[1] == "commit":
                resolved.append((recorded, parts[0]))
        if not resolved:
            return self._candidates
        meta = _git(self.root, "log", "--no-walk=unsorted", "--format=%H%x1f%aI%x1f%ae%x1f%s%x1e", *[sha for _, sha in resolved])
        keys = {}
        for chunk in (meta or "").split("\x1e"):
            fields = chunk.strip("\n").split("\x1f")
            if len(fields) == 4:
                keys[fields[0]] = (fields[1], fields[2].lower(), fields[3])
        self._candidates = [{"recorded": rec, "sha": sha, "key": keys.get(sha)} for rec, sha in resolved]
        return self._candidates

    def patch_id(self, sha: str) -> str:
        if sha in self._patch:
            return self._patch[sha]
        value = ""
        if self.deadline is None or time.monotonic() < self.deadline:
            diff = _git(self.root, "diff-tree", "--root", "-p", "--no-color", sha)
            if diff:
                out = _git(self.root, "patch-id", "--stable", stdin=diff)
                value = out.split()[0] if out and out.split() else ""
            self._patch[sha] = value
            self._dirty = True
        return value

    def save(self) -> None:
        if not (self.cache_path and self._dirty):
            return
        try:
            self.cache_path.parent.mkdir(parents=True, exist_ok=True)
            temporary = self.cache_path.with_suffix(".tmp")
            temporary.write_text(json.dumps({"patch": self._patch}, sort_keys=True), encoding="utf-8")
            temporary.replace(self.cache_path)
            self._dirty = False
        except OSError:
            pass

    def find(self, info: dict[str, Any]) -> list[dict[str, Any]]:
        candidates = [c for c in self.candidates() if c["sha"] != info["sha"]]
        if not candidates:
            return []
        key = (info["date"], info["email"].lower(), info["subject"])
        target = self.patch_id(info["sha"])
        matches = []
        for candidate in candidates:
            if target and self.patch_id(candidate["sha"]) == target:
                kind = "patch-id"
            elif candidate["key"] == key:
                kind = "author-date+email+subject"
            else:
                continue
            matches.append({"recorded": candidate["recorded"], "sha": candidate["sha"], "kind": kind})
        self.save()
        return matches


class DirectFacts:
    """Compute facts straight from git (always correct; slower on large histories)."""

    engine = "direct"

    def __init__(self, root: Path, sessions: list[dict[str, Any]], ledger: list[dict[str, Any]], cache_path: Path | None = None) -> None:
        self.root = root
        self.equivalence = Equivalence(root, sessions, ledger, cache_path)

    def info(self, rev: str) -> dict[str, Any] | None:
        return tr.commit_info(self.root, rev)

    def for_pr(self, number: str) -> list[str]:
        return tr.commits_for_pr(self.root, number)

    def for_session(self, session_id: str) -> list[str]:
        return tr.commits_for_session(self.root, session_id)

    def mentioning(self, number: str) -> list[str]:
        return tr.commits_mentioning(self.root, number)

    def equivalents(self, info: dict[str, Any]) -> list[dict[str, Any]]:
        return self.equivalence.find(info)


# ---------------------------------------------------------------- projection

def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else ""


def source_digests(root: Path, index: Path, ledger: Path) -> dict[str, str]:
    refs = _git(root, "for-each-ref", "--format=%(objectname)", "refs/heads", "refs/remotes", "refs/tags") or ""
    return {"root": str(root.resolve()), "refs": hashlib.sha256(refs.encode()).hexdigest(),
            "index": file_digest(index), "ledger": file_digest(ledger)}


def parse_log(output: str) -> list[dict[str, Any]]:
    commits = []
    for chunk in output.split("\x1e"):
        fields = chunk.lstrip("\n").split("\x1f", 5)
        if len(fields) == 6:
            sha, name, email, date, subject, body = fields
            commits.append({"sha": sha, "author": name, "email": email, "date": date, "subject": subject, "message": body.strip()})
    return commits


def build_projection(connection: sqlite3.Connection, root: Path, sessions: list[dict[str, Any]], ledger: list[dict[str, Any]],
                     index: Path, ledger_path: Path, cache_path: Path | None, budget_seconds: float = 25.0) -> int:
    """Write commits and trace edges (commit/session/PR/issue/run/equivalence). Returns commit count."""
    for table in ("trace_edges", "git_commits", "trace_meta"):
        connection.execute(f"DELETE FROM {table}")
    edges: set[tuple[str, str, str, str, str, str]] = set()

    def edge(src_type: str, src: str, dst_type: str, dst: str, kind: str, via: str = "") -> None:
        edges.add((src_type, src, dst_type, dst, kind, via))

    log = _git(root, "log", *tr.REFS, f"--format={LOG_FORMAT}", timeout=120) or ""
    commits = parse_log(log)
    equivalence = Equivalence(root, sessions, ledger, cache_path, deadline=time.monotonic() + budget_seconds)
    budget_left = EQUIVALENCE_TARGET_LIMIT
    for info in commits:
        connection.execute("INSERT OR REPLACE INTO git_commits(sha, author, email, authored_at, subject, message) VALUES (?,?,?,?,?,?)",
                           (info["sha"], info["author"], info["email"], info["date"], info["subject"], info["message"]))
        declared = tr.declared_sessions(info["message"])
        for value in declared:
            edge("commit", info["sha"], "session", value, "trailer")
        for pr in tr.commit_prs(info):
            edge("commit", info["sha"], "pr", pr, "subject")
        for issue in tr.commit_issues(info):
            edge("commit", info["sha"], "issue", issue, "closes")
        for number in unique_numbers(info["message"]):
            edge("commit", info["sha"], "ref", f"#{number}", "mentions")
        if not declared and budget_left > 0 and not tr.is_bot(info["author"], info["email"]):
            budget_left -= 1
            for match in equivalence.find(info):
                edge("commit", info["sha"], "commit", match["recorded"], "equivalent", match["kind"])
    for record in sessions:
        sid = record.get("session_id")
        if not isinstance(sid, str):
            continue
        for field, dst_type in (("prs", "pr"), ("issues", "issue"), ("commits", "commit")):
            for value in record.get(field, []):
                number = tr.number_of(str(value)) if dst_type != "commit" else None
                edge("session", sid, dst_type, f"#{number}" if number else str(value), "index")
    for entry in ledger:
        sid = entry.get("session_id")
        if not isinstance(sid, str):
            continue
        for field, dst_type in (("prs", "pr"), ("issues", "issue"), ("commits", "commit")):
            for value in entry.get(field, []):
                number = tr.number_of(str(value)) if dst_type != "commit" else None
                edge("session", sid, dst_type, f"#{number}" if number else str(value), "ledger")
        if entry.get("run_id"):
            edge("session", sid, "run", str(entry["run_id"]), "ledger")
    connection.executemany("INSERT OR IGNORE INTO trace_edges(src_type, src_id, dst_type, dst_id, kind, via) VALUES (?,?,?,?,?,?)", sorted(edges))
    for key, value in source_digests(root, index, ledger_path).items():
        connection.execute("INSERT OR REPLACE INTO trace_meta(key, value) VALUES (?, ?)", (key, value))
    return len(commits)


def unique_numbers(message: str) -> list[str]:
    return tr.unique(re.findall(r"(?<![\w#])#(\d+)(?!\d)", message))


class ProjectionFacts:
    """Facts served from the SQLite projection; only used while it is fresh."""

    engine = "projection"

    def __init__(self, connection: sqlite3.Connection, direct: DirectFacts) -> None:
        self.connection, self.direct = connection, direct

    @classmethod
    def open(cls, database: Path, root: Path, index: Path, ledger_path: Path, direct: DirectFacts) -> "ProjectionFacts | None":
        if not database.is_file():
            return None
        try:
            connection = sqlite3.connect(f"file:{database}?mode=ro", uri=True)
            connection.row_factory = sqlite3.Row
            facts = cls.from_connection(connection, root, index, ledger_path, direct)
            if facts is None:
                connection.close()
            return facts
        except sqlite3.Error:
            return None

    @classmethod
    def from_connection(cls, connection: sqlite3.Connection, root: Path, index: Path, ledger_path: Path,
                        direct: DirectFacts) -> "ProjectionFacts | None":
        """Use the projection only when its recorded source digests match the working tree."""
        try:
            meta = {row[0]: row[1] for row in connection.execute("SELECT key, value FROM trace_meta")}
        except sqlite3.Error:
            return None
        return cls(connection, direct) if meta and meta == source_digests(root, index, ledger_path) else None

    def info(self, rev: str) -> dict[str, Any] | None:
        sha = rev if re.fullmatch(r"[0-9a-f]{40}", rev) else None
        if sha is None:
            resolved = (_git(self.direct.root, "rev-parse", "--verify", "--quiet", f"{rev}^{{commit}}") or "").strip()
            sha = resolved or None
        row = self.connection.execute("SELECT * FROM git_commits WHERE sha = ?", (sha,)).fetchone() if sha else None
        if row is None:
            return self.direct.info(rev)
        return {"sha": row["sha"], "author": row["author"], "email": row["email"], "date": row["authored_at"],
                "subject": row["subject"], "message": row["message"]}

    def _commits(self, dst_type: str, dst_id: str, kind: str) -> list[str]:
        rows = self.connection.execute(
            "SELECT e.src_id FROM trace_edges e JOIN git_commits c ON c.sha = e.src_id "
            "WHERE e.src_type='commit' AND e.dst_type=? AND e.dst_id=? AND e.kind=? ORDER BY c.authored_at DESC",
            (dst_type, dst_id, kind)).fetchall()
        return [row[0] for row in rows]

    def for_pr(self, number: str) -> list[str]:
        return self._commits("pr", f"#{number.lstrip('#')}", "subject")

    def mentioning(self, number: str) -> list[str]:
        return self._commits("ref", f"#{number.lstrip('#')}", "mentions")

    def for_session(self, session_id: str) -> list[str]:
        native = tr.native_part(session_id)
        rows = self.connection.execute(
            "SELECT src_id, dst_id FROM trace_edges WHERE src_type='commit' AND dst_type='session' AND kind='trailer' AND dst_id LIKE ?",
            (f"%{native}",)).fetchall()
        return [row[0] for row in rows if tr.same_session(session_id, row[1])]

    def equivalents(self, info: dict[str, Any]) -> list[dict[str, Any]]:
        rows = self.connection.execute(
            "SELECT dst_id, via FROM trace_edges WHERE src_type='commit' AND src_id=? AND dst_type='commit' AND kind='equivalent'",
            (info["sha"],)).fetchall()
        return [{"recorded": row[0], "sha": row[0], "kind": row[1]} for row in rows]

    def commit_sessions(self, sha: str) -> list[str]:
        return [row[0] for row in self.connection.execute(
            "SELECT dst_id FROM trace_edges WHERE src_type='commit' AND src_id=? AND dst_type='session' AND kind='trailer'", (sha,))]


def search_commits(connection: sqlite3.Connection, term: str, limit: int) -> list[dict[str, Any]]:
    """Commits whose subject or body contain every word of `term` (projection table)."""
    words = [w for w in term.split() if w]
    if not words:
        return []
    clause = " AND ".join("(lower(subject) LIKE ? OR lower(message) LIKE ?)" for _ in words)
    params: list[Any] = []
    for word in words:
        params += [f"%{word.lower()}%"] * 2
    rows = connection.execute(f"SELECT sha, subject FROM git_commits WHERE {clause} ORDER BY authored_at DESC LIMIT ?", (*params, limit)).fetchall()
    return [{"sha": row[0], "subject": row[1]} for row in rows]
