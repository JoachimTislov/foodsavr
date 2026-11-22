#!/usr/bin/env python3
"""Session identity, trailers, refs, trace, PR check, and provenance (#271).

Pure functions over explicit inputs (repo root, loaded session/ledger records)
so they run offline, in CI, and in tests. Stdlib only. `gh` is used only when
the caller opts in, with a hard timeout.
"""

from __future__ import annotations

import json
import os
import re
import glob
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping

sys.path.insert(0, str(Path(__file__).resolve().parent))

TRAILER = "Agent-Session"
HUMAN = "human"
# Records stamped before this instant predate traceability enforcement.
CUTOFF = "2026-11-21T17:00:00+00:00"

# Table-driven harness detection: add a harness by adding one row.
# (environment variable, harness, provider). Order is priority.
# T3 Code threads come first: sessions on main are recorded as `t3-code:<thread id>`; the
# inner harness (claude-code, codex) is kept as a related session.
SESSION_ENV: list[tuple[str, str, str]] = [
    ("T3CODE_THREAD_ID", "t3-code", "unknown"),
    ("CLAUDE_CODE_SESSION_ID", "claude-code", "anthropic"),
    ("CODEX_THREAD_ID", "codex", "openai"),
]
OVERRIDE_ENV = "AGENT_SESSION_ID"

SESSION_RE = re.compile(r"^[a-z][a-z0-9-]*:[A-Za-z0-9._/@+:=-]{1,200}$")
NATIVE_RE = re.compile(r"^[A-Za-z0-9._/@+:=-]{1,200}$")
PREFIX_RE = re.compile(r"^[a-z][a-z0-9-]*:")
HUMAN_RE = re.compile(r"^(?:none\s*\(human\)|human)$", re.I)
TRAILER_RE = re.compile(rf"^[ \t>*-]*{TRAILER}:[ \t]*(.+?)[ \t]*$", re.I | re.M)
PR_URL_RE = re.compile(r"^https?://github\.com/([^/]+/[^/]+)/pull/(\d+)/?$")
ISSUE_URL_RE = re.compile(r"^https?://github\.com/([^/]+/[^/]+)/issues/(\d+)/?$")
RUN_URL_RE = re.compile(r"^https?://github\.com/([^/]+/[^/]+)/actions/runs/(\d+)")
COMMIT_URL_RE = re.compile(r"^https?://github\.com/([^/]+/[^/]+)/commit/([0-9a-f]{7,40})", re.I)
HEX_RE = re.compile(r"^[0-9a-f]{7,40}$", re.I)
CLOSES_RE = re.compile(r"(?i)\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s*:?\s+#(\d+)")
GH_TIMEOUT = 10


# ---------------------------------------------------------------- identity

class Identity:
    def __init__(self, session_id: str, harness: str, provider: str, related: list[str], source: str) -> None:
        self.session_id, self.harness, self.provider = session_id, harness, provider
        self.related, self.source = related, source

    def as_dict(self) -> dict[str, Any]:
        return {"session_id": self.session_id, "harness": self.harness, "provider": self.provider,
                "related": self.related, "detected_from": self.source}


def native_part(session_id: str) -> str:
    return PREFIX_RE.sub("", session_id, count=1)


def same_session(a: str, b: str) -> bool:
    """Legacy bare IDs and `<harness>:<id>` forms of one native ID are one session."""
    return a == b or (bool(native_part(a)) and native_part(a) == native_part(b))


def normalize_session_id(raw: str, harness: str | None = None) -> str:
    value = raw.strip()
    if HUMAN_RE.match(value):
        return HUMAN
    if not PREFIX_RE.match(value):
        if not harness:
            raise ValueError(f"session id needs a '<harness>:' prefix: {raw!r}")
        value = f"{harness}:{value}"
    if not SESSION_RE.match(value):
        raise ValueError(f"invalid session id: {raw!r}")
    return value


def detect_github_actions(env: Mapping[str, str]) -> str | None:
    run, repo = env.get("GITHUB_RUN_ID"), env.get("GITHUB_REPOSITORY")
    if env.get("GITHUB_ACTIONS") == "true" and run and repo:
        candidate = f"github-actions:{repo}/{run}/{env.get('GITHUB_RUN_ATTEMPT') or '1'}"
        return candidate if SESSION_RE.match(candidate) else None
    return None


def detect_session(env: Mapping[str, str] | None = None) -> Identity | None:
    """Derive the current session from the environment. Reads only known ID variables."""
    env = os.environ if env is None else env
    override = (env.get(OVERRIDE_ENV) or "").strip()
    found: list[tuple[str, str, str, str]] = []  # (session_id, harness, provider, env var)
    if override:
        try:
            sid = normalize_session_id(override, env.get("AGENT_HARNESS") or "agent")
            found.append((sid, sid.split(":", 1)[0], env.get("AGENT_PROVIDER") or "unknown", OVERRIDE_ENV))
        except ValueError:
            pass
    for variable, harness, provider in SESSION_ENV:
        value = (env.get(variable) or "").strip()
        if value and NATIVE_RE.match(value):
            found.append((f"{harness}:{value}", harness, provider, variable))
    actions = detect_github_actions(env)
    if actions:
        found.append((actions, "github-actions", "github", "GITHUB_RUN_ID"))
    if not found:
        return None
    primary = found[0]
    related = [item[0] for item in found[1:] if item[0] != primary[0]]
    provider = primary[2]
    if provider == "unknown":  # a wrapper such as T3 Code runs some provider's agent
        provider = next((item[2] for item in found[1:] if item[2] not in {"unknown", "github"}), "unknown")
    return Identity(primary[0], primary[1], provider, related, primary[3])


# -------------------------------------------------------------------- refs

def repo_slug(root: Path, env: Mapping[str, str] | None = None) -> str | None:
    env = os.environ if env is None else env
    if env.get("GITHUB_REPOSITORY"):
        return env["GITHUB_REPOSITORY"]
    remote = run_git(root, "remote", "get-url", "origin")
    match = re.search(r"github\.com[:/]([^/]+/[^/.\s]+?)(?:\.git)?$", (remote or "").strip())
    return match.group(1) if match else None


def normalize_number_ref(raw: str, kind: str, slug: str | None = None) -> str:
    """Canonical form for PRs and issues is `#N`; foreign-repo URLs stay as full URLs."""
    value = raw.strip()
    pattern = PR_URL_RE if kind == "pr" else ISSUE_URL_RE
    match = pattern.match(value)
    if match:
        return f"#{match.group(2)}" if not slug or match.group(1).lower() == slug.lower() else value
    match = re.fullmatch(r"(?i)(?:pr|pull|issue)?\s*#?\s*(\d+)", value)
    if match:
        return f"#{int(match.group(1))}"
    raise ValueError(f"invalid {kind} reference: {raw!r} (use #N or a GitHub URL)")


def normalize_commit(raw: str, root: Path | None = None) -> str:
    value = raw.strip()
    match = COMMIT_URL_RE.match(value)
    if match:
        value = match.group(2)
    if root is not None:
        full = run_git(root, "rev-parse", "--verify", "--quiet", f"{value}^{{commit}}")
        if full and HEX_RE.match(full.strip()):
            return full.strip().lower()
    if HEX_RE.match(value):
        return value.lower()
    raise ValueError(f"invalid commit reference: {raw!r}")


def number_of(ref: str) -> int | None:
    match = re.search(r"(?:#|/(?:pull|issues)/|^)(\d+)/?$", ref.strip())
    return int(match.group(1)) if match else None


def unique(values: list[str]) -> list[str]:
    return list(dict.fromkeys(values))


# --------------------------------------------------------------------- git

def run_git(root: Path, *args: str, timeout: int = 20) -> str | None:
    try:
        result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True,
                                timeout=timeout, stdin=subprocess.DEVNULL, check=False)
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout if result.returncode == 0 else None


def gh_json(args: list[str], timeout: int = GH_TIMEOUT) -> Any | None:
    """Optional enrichment. Never raises, never blocks longer than `timeout`."""
    if not shutil.which("gh"):
        return None
    try:
        result = subprocess.run(["gh", *args], capture_output=True, text=True, timeout=timeout,
                                stdin=subprocess.DEVNULL, check=False,
                                env={**os.environ, "GH_PROMPT_DISABLED": "1", "NO_COLOR": "1"})
        return json.loads(result.stdout) if result.returncode == 0 and result.stdout.strip() else None
    except (OSError, subprocess.SubprocessError, ValueError):
        return None


def commit_info(root: Path, rev: str) -> dict[str, Any] | None:
    out = run_git(root, "log", "-1", "--format=%H%x1f%an%x1f%ae%x1f%aI%x1f%s%x1f%B", rev, "--")
    if not out or "\x1f" not in out:
        return None
    sha, name, email, date, subject, body = out.split("\x1f", 5)
    return {"sha": sha.strip(), "author": name, "email": email, "date": date, "subject": subject, "message": body.strip()}


def commit_prs(info: Mapping[str, Any]) -> list[str]:
    subject = info["subject"]
    numbers = re.findall(r"\(#(\d+)\)\s*$", subject) + re.findall(r"^Merge pull request #(\d+)", subject)
    return [f"#{n}" for n in unique(numbers)]


def commit_issues(info: Mapping[str, Any]) -> list[str]:
    return [f"#{n}" for n in unique(CLOSES_RE.findall(info["message"]))]


def declared_sessions(text: str) -> list[str]:
    """Valid `Agent-Session:` values (session IDs or the human marker) found anywhere in text.

    Parsed line-wise, not as a trailer block: a GitHub squash body concatenates
    the original commit messages, so trailers are no longer the last paragraph.
    """
    result = []
    for value in TRAILER_RE.findall(text or ""):
        value = value.strip()
        if HUMAN_RE.match(value):
            result.append(HUMAN)
        elif SESSION_RE.match(value):
            result.append(value)
    return unique(result)


REFS = ["--branches", "--remotes", "--tags"]


def git_log_shas(root: Path, *args: str) -> list[str]:
    out = run_git(root, "log", *REFS, "--format=%H", *args)
    return out.split() if out else []


def commits_for_pr(root: Path, number: str) -> list[str]:
    n = number.lstrip("#")
    shas = git_log_shas(root, "--fixed-strings", f"--grep=#{n}")
    result = []
    for sha in shas:
        info = commit_info(root, sha)
        if info and f"#{n}" in commit_prs(info):
            result.append(sha)
    return result


def session_commit_rows(root: Path, session_id: str) -> list[dict[str, str]]:
    """Commits carrying `Agent-Session: <id>` (what `agentctl sessions commits` lists).

    The one implementation of commit-by-trailer lookup; legacy bare and prefixed IDs of the
    same native ID match, and trailers are read line-wise so squash bodies work too.
    """
    out = run_git(root, "log", "--all", "--fixed-strings", f"--grep={native_part(session_id)}", "--format=%H%x1f%cI%x1f%s%x1f%B%x1e")
    rows = []
    for chunk in (out or "").split("\x1e"):
        fields = chunk.lstrip("\n").split("\x1f", 3)
        if len(fields) == 4 and any(same_session(session_id, value) for value in declared_sessions(fields[3])):
            rows.append(dict(zip(("sha", "committed_at", "subject"), fields[:3])))
    return rows


def commits_for_session(root: Path, session_id: str) -> list[str]:
    return [row["sha"] for row in session_commit_rows(root, session_id)]


def commits_mentioning(root: Path, number: str) -> list[str]:
    n = number.lstrip("#")
    result = []
    for sha in git_log_shas(root, "--fixed-strings", f"--grep=#{n}"):
        info = commit_info(root, sha)
        if info and re.search(rf"(?<![\w#]){re.escape('#' + n)}(?!\d)", info["message"]):
            result.append(sha)
    return result


# ------------------------------------------------------------------- hooks

def prepare_commit_msg(root: Path, message_file: str, source: str = "", env: Mapping[str, str] | None = None) -> bool:
    """Append the Agent-Session trailer when a session is detected. Never raises."""
    try:
        identity = detect_session(env)
        if identity is None or source in {"merge"}:
            return False
        path = Path(message_file)
        if identity.session_id in declared_sessions(path.read_text(encoding="utf-8", errors="replace")):
            return False
        result = subprocess.run(
            ["git", "-C", str(root), "interpret-trailers", "--in-place", "--if-exists", "addIfDifferent",
             "--trailer", f"{TRAILER}: {identity.session_id}", str(path.resolve())],
            capture_output=True, text=True, timeout=15, stdin=subprocess.DEVNULL, check=False)
        return result.returncode == 0
    except Exception:  # a hook must never block a commit
        return False


def hooks_status(root: Path) -> dict[str, Any]:
    configured = (run_git(root, "config", "--get", "core.hooksPath") or "").strip()
    hook = root / ".githooks" / "prepare-commit-msg"
    installed = bool(configured) and (root / configured).resolve() == (root / ".githooks").resolve()
    return {"core.hooksPath": configured or None, "installed": installed and hook.exists(),
            "hook_present": hook.exists(), "hint": None if installed else "run: make hooks"}


# ------------------------------------------------------------------- trace

def parse_time(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def record_time(record: Mapping[str, Any]) -> datetime | None:
    return parse_time(record.get("timestamp")) or parse_time(record.get("date")) or parse_time(record.get("started_at"))


def is_legacy(record: Mapping[str, Any]) -> bool:
    moment = record_time(record)
    return moment is not None and moment < parse_time(CUTOFF)  # type: ignore[operator]


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    result = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            value = json.loads(line)
        except ValueError:
            continue
        if isinstance(value, dict):
            result.append(value)
    return result


def fold_records(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Fold duplicate session_id lines: arrays union, latest scalar wins, attempts kept.

    Parallel branches append to the index (`merge=union`), so one session may
    appear on several lines. Reading always folds; `agentctl maintain` compacts.
    """
    merged: dict[str, dict[str, Any]] = {}
    result: list[dict[str, Any]] = []
    for row in rows:
        key = row.get("session_id")
        if not isinstance(key, str):
            result.append(row)
            continue
        target = merged.get(key)
        if target is None:
            merged[key] = target = {}
            result.append(target)
        for field, value in row.items():
            if isinstance(value, list):
                current = target.setdefault(field, [])
                current.extend(item for item in value if item not in current)
            else:
                target[field] = value
    return result


# Session locators: how to reopen a session, per harness. One row per harness.
# `transcripts` are (base dir, glob) pairs; only paths are reported, never contents.
LOCATORS: dict[str, dict[str, Any]] = {
    "claude-code": {"open": "claude --resume {native}", "transcripts": [("~/.claude/projects", "*/{native}.jsonl")]},
    "codex": {"open": "codex resume {native}", "transcripts": [("~/.codex/sessions", "*/*/*/*{native}*.jsonl")]},
    "t3-code": {"open": "open thread {native} in T3 Code", "transcripts": []},
}
HARNESS_ALIASES = {"claude": "claude-code", "t3": "t3-code"}
ACTIONS_RE = re.compile(r"^(?P<repo>[^/]+/[^/]+)/(?P<run>\d+)(?:/(?P<attempt>\d+))?$")


def locate(session_id: str, record: Mapping[str, Any] | None = None, home: Path | None = None) -> dict[str, Any]:
    """Say how to open a session and whether its transcript is on this machine."""
    harness = session_id.split(":", 1)[0] if PREFIX_RE.match(session_id) else str((record or {}).get("harness") or "")
    harness = HARNESS_ALIASES.get(harness, harness)
    native = native_part(session_id)
    result: dict[str, Any] = {"session_id": session_id, "harness": harness, "open": None, "transcript": None, "available_locally": False}
    if harness == "github-actions":
        match = ACTIONS_RE.match(native)
        if match:
            url = f"https://github.com/{match['repo']}/actions/runs/{match['run']}/attempts/{match['attempt'] or 1}"
            result.update(open=url, url=url)
        return result
    spec = LOCATORS.get(harness)
    if spec is None or not NATIVE_RE.match(native):
        return result
    result["open"] = spec["open"].format(native=native)
    base_home = home or Path.home()
    for base, pattern in spec["transcripts"]:
        root = Path(base.replace("~", str(base_home), 1))
        if harness == "claude-code" and not home and os.environ.get("CLAUDE_CONFIG_DIR"):
            root = Path(os.environ["CLAUDE_CONFIG_DIR"]) / "projects"
        found = sorted(root.glob(pattern.format(native=glob.escape(native)))) if root.is_dir() else []
        if found:
            result.update(transcript=str(found[0]), available_locally=True)
            break
    return result


def find_record(sessions: list[dict[str, Any]], session_id: str) -> dict[str, Any] | None:
    for record in sessions:
        ids = [record.get("session_id", ""), *record.get("related", [])]
        if any(item and same_session(session_id, item) for item in ids):
            return record
    return None


TEXT_SHA_RE = re.compile(r"(?<![0-9A-Za-z-])(?=[0-9a-f]*\d)(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}(?![0-9A-Za-z-])")


def row_shas(row: Mapping[str, Any]) -> list[str]:
    """Commit SHAs a log row recorded: its `commits` field plus SHAs quoted in its text (legacy events)."""
    text = f"{row.get('event', '')} {row.get('summary', '')}"
    return unique([str(c) for c in row.get("commits", [])] + TEXT_SHA_RE.findall(text))


def session_end(record: Mapping[str, Any], sessions: list[dict[str, Any]]) -> tuple[datetime | None, str]:
    """End of a session's time window: ended_at, else last timestamp it recorded, else the next session of the same harness."""
    ended = parse_time(record.get("ended_at"))
    if ended:
        return ended, "ended_at"
    stamps = [parse_time(record.get(k)) for k in ("completed_at", "updated_at")]
    stamps += [parse_time(a.get(k)) for a in record.get("attempts", []) if isinstance(a, dict) for k in ("completed_at", "timestamp")]
    stamps = [s for s in stamps if s]
    if stamps:
        return max(stamps), "last recorded activity"
    start = parse_time(record.get("started_at"))
    later = [s for s in (parse_time(r.get("started_at")) for r in sessions
                         if r is not record and r.get("harness") == record.get("harness")) if s and start and s > start]
    return (min(later), "next session start on the same harness") if later else (None, "open-ended")


def sha_match(a: str, b: str) -> bool:
    a, b = a.lower(), b.lower()
    return len(a) >= 7 and len(b) >= 7 and (a.startswith(b) or b.startswith(a))


def ref_numbers(values: Any) -> set[int]:
    return {n for n in (number_of(str(v)) for v in values or []) if n is not None}


def classify(root: Path, ref: str, sessions: list[dict[str, Any]]) -> tuple[str, str]:
    value = ref.strip()
    for pattern, kind in ((PR_URL_RE, "pr"), (ISSUE_URL_RE, "issue"), (RUN_URL_RE, "run"), (COMMIT_URL_RE, "commit")):
        match = pattern.match(value)
        if match:
            return kind, match.group(2)
    explicit = re.match(r"^(pr|issue|run|commit):(.+)$", value)
    if explicit:
        return explicit.group(1), explicit.group(2).lstrip("#")
    if re.fullmatch(r"#\d+", value):
        return "number", value[1:]
    if re.fullmatch(r"\d+", value):
        return ("run", value) if len(value) >= 8 else ("number", value)
    located = re.fullmatch(r"(.+):(\d+)", value)
    if located and (root / located.group(1)).is_file():
        return "line", value
    if PREFIX_RE.match(value) or find_record(sessions, value):
        return "session", value
    if run_git(root, "rev-parse", "--verify", "--quiet", f"{value}^{{commit}}"):
        return "commit", value
    if HEX_RE.match(value):
        return "commit", value  # unknown to git: may still appear in logs
    raise ValueError(f"cannot interpret {ref!r}: expected commit, #N, PR/issue/run URL, path:line, or session id")


class Tracer:
    def __init__(self, root: Path, sessions: list[dict[str, Any]], ledger: list[dict[str, Any]], online: bool = False,
                 facts: Any = None, infer: bool = False) -> None:
        self.root, self.sessions, self.ledger, self.online, self.infer = root, sessions, ledger, online, infer
        if facts is None:
            from trace_facts import DirectFacts
            facts = DirectFacts(root, sessions, ledger)
        self.facts = facts
        self.commits: dict[str, dict[str, Any]] = {}
        self.session_via: dict[str, set[str]] = {}
        self.prs: set[str] = set()
        self.issues: set[str] = set()
        self.ledger_hits: dict[int, dict[str, Any]] = {}
        self.gaps: list[str] = []
        self.notes: list[str] = []
        self.pr_titles: dict[str, str] = {}

    # collectors
    def add_session(self, session_id: str, via: str) -> None:
        for known in self.session_via:
            if same_session(known, session_id):
                self.session_via[known].add(via)
                return
        self.session_via[session_id] = {via}

    def add_ledger(self, index: int, via: str) -> None:
        entry = self.ledger[index]
        self.ledger_hits[index] = entry
        if isinstance(entry.get("session_id"), str):
            self.add_session(entry["session_id"], f"ledger:{via}")

    def sessions_with(self, field: str, number: int) -> list[dict[str, Any]]:
        return [r for r in self.sessions if number in ref_numbers(r.get(field))]

    def ledger_with(self, field: str, number: int) -> list[int]:
        return [i for i, e in enumerate(self.ledger) if number in ref_numbers(e.get(field))
                or (field == "prs" and number in ref_numbers(e.get("references", {}).get("prs")))]

    def add_commit(self, rev: str, via: str, deep: bool = True) -> dict[str, Any] | None:
        info = self.facts.info(rev)
        if info is None:
            return None
        sha = info["sha"]
        if sha in self.commits:
            return self.commits[sha]
        info = dict(info)
        info["prs"], info["issues"] = commit_prs(info), commit_issues(info)
        info["sessions"] = declared_sessions(info["message"])
        info["via"] = via
        info["equivalents"] = []
        self.commits[sha] = info
        for value in info["sessions"]:
            self.add_session(value, "trailer")
        if deep:
            for pr in info["prs"]:
                self.pr(pr, from_commit=True)
            self.issues.update(info["issues"])
            self.link_recorded(sha, f"commit {sha[:9]}")
            if not info["sessions"]:
                self.link_equivalents(info)
            if self.online and not self.session_via_for(info):
                self.link_online_prs(info)
            if self.infer and not self.session_via_for(info):
                self.link_inferred(info)
        if not info["sessions"] and not self.session_via_for(info):
            self.gaps.append(f"commit {sha[:9]} has no {TRAILER} trailer and no recorded session")
        elif not info["sessions"]:
            self.notes.append(f"commit {sha[:9]} has no {TRAILER} trailer; sessions resolved from logs")
        return info

    def session_via_for(self, info: dict[str, Any]) -> bool:
        return bool(info["sessions"] or info["equivalents"] or any(
            any(sha_match(info["sha"], str(c)) for c in row_shas(row)) for row in (*self.sessions, *self.ledger)))

    def link_recorded(self, sha: str, label: str, source: str | None = None) -> None:
        """Attach ledger events and index sessions that recorded this SHA."""
        for index, entry in enumerate(self.ledger):
            if any(sha_match(sha, str(c)) for c in row_shas(entry)):
                self.add_ledger(index, source or label)
        for record in self.sessions:
            if any(sha_match(sha, str(c)) for c in row_shas(record)):
                self.add_session(record["session_id"], f"index:{source or label}")
                for pr in record.get("prs", []):
                    self.pr(str(pr), from_commit=True)

    def link_equivalents(self, info: dict[str, Any]) -> None:
        """Rebase rewrites SHAs: reach logs that recorded the pre-rebase commit."""
        for match in self.facts.equivalents(info):
            label = f"rebase-equivalent {match['recorded'][:7]} ({match['kind']})"
            info["equivalents"].append({k: match[k] for k in ("recorded", "kind")})
            self.link_recorded(match["recorded"], label, label)
            old = self.facts.info(match["sha"])
            if old:
                for value in declared_sessions(old["message"]):
                    self.add_session(value, label)

    def link_inferred(self, info: dict[str, Any]) -> None:
        """Opt-in guess: sessions whose time window brackets the commit. Never persisted or counted as coverage."""
        stamp = (run_git(self.root, "log", "-1", "--format=%cI", info["sha"]) or "").strip()
        moment = parse_time(stamp) or parse_time(info["date"])
        if moment is None:
            return
        refs = {int(p[1:]) for p in [*info["prs"], *info["issues"]]}
        for record in self.sessions:
            start = parse_time(record.get("started_at"))
            end, end_source = session_end(record, self.sessions)
            if start is None or end is None or not (start <= moment <= end):
                continue
            overlap = refs & (ref_numbers(record.get("prs")) | ref_numbers(record.get("issues")))
            if refs and not overlap:
                continue
            evidence = f"{start.isoformat()}..{end.isoformat()} ({end_source}) brackets commit time {moment.isoformat()}"
            evidence += f"; shares {', '.join('#' + str(n) for n in sorted(overlap))}" if overlap else "; time only (commit names no PR/issue)"
            self.add_session(record["session_id"], f"inferred: {evidence}")

    def link_online_prs(self, info: dict[str, Any]) -> None:
        data = gh_json(["api", f"repos/{{owner}}/{{repo}}/commits/{info['sha']}/pulls"])
        if not isinstance(data, list) or not data:
            self.notes.append(f"gh could not resolve a PR for commit {info['sha'][:9]}")
            return
        for item in data:
            if isinstance(item, dict) and item.get("number"):
                self.pr(f"#{item['number']}", from_commit=True)
                self.notes.append(f"commit {info['sha'][:9]} belongs to PR #{item['number']} (gh)")

    def pr(self, ref: str, from_commit: bool = False) -> None:
        number = number_of(ref)
        if number is None or f"#{number}" in self.prs:
            return
        self.prs.add(f"#{number}")
        for record in self.sessions_with("prs", number):
            self.add_session(record["session_id"], f"index:pr #{number}")
        for index in self.ledger_with("prs", number):
            self.add_ledger(index, f"pr #{number}")
        if not from_commit:
            for sha in self.facts.for_pr(f"#{number}"):
                self.add_commit(sha, f"merge of #{number}")
            if not any(f"#{number}" in c["prs"] for c in self.commits.values()):
                # Rebase merges carry no (#N) subject: infer commits from the PR's sessions' trailers.
                for record in self.sessions_with("prs", number):
                    for sha in self.facts.for_session(record["session_id"]):
                        self.add_commit(sha, f"trailer of a session on #{number} (inferred)")
                self.notes.append(f"PR #{number} is not named in any commit subject (rebase merge); commits are inferred from session trailers, use --online for exact ones")
        if self.online:
            data = gh_json(["pr", "view", str(number), "--json", "title,body,state,mergeCommit,commits,url"])
            if data:
                self.pr_titles[f"#{number}"] = f"{data.get('title', '')} [{data.get('state', '')}]"
                for value in declared_sessions(data.get("body") or ""):
                    self.add_session(value, f"pr-body #{number}")
                oid = (data.get("mergeCommit") or {}).get("oid")
                if oid and not from_commit:
                    # Rebase merge (this repo's policy): mergeCommit is the tip of N rewritten commits.
                    count = max(len(data.get("commits") or []), 1)
                    tips = (run_git(self.root, "rev-list", f"--max-count={count}", oid) or oid).split()
                    for sha in tips:
                        self.add_commit(sha, f"merge of #{number} (gh)")
            else:
                self.notes.append(f"gh enrichment unavailable for #{number}")

    def issue(self, ref: str, force: bool = True) -> None:
        number = number_of(ref)
        if number is None:
            return
        hits = False
        for record in self.sessions_with("issues", number):
            self.add_session(record["session_id"], f"index:issue #{number}")
            hits = True
        for index in self.ledger_with("issues", number):
            self.add_ledger(index, f"issue #{number}")
            hits = True
        for sha in self.facts.mentioning(f"#{number}"):
            info = self.facts.info(sha)
            if info and f"#{number}" in commit_prs(info):
                continue  # the PR's own squash commit, not an issue mention
            self.add_commit(sha, f"mentions #{number}", deep=False)
            hits = True
        if force or hits:
            self.issues.add(f"#{number}")

    def session(self, session_id: str) -> None:
        self.add_session(session_id, "query")
        record = find_record(self.sessions, session_id)
        aliases = [session_id] + ([record["session_id"], *record.get("related", [])] if record else [])
        if record is None:
            self.gaps.append(f"session {session_id} is not registered in the session index")
        else:
            for ref in record.get("commits", []):
                self.add_commit(str(ref), "index", deep=False)
            for ref in record.get("prs", []):
                self.pr(str(ref))
            for ref in record.get("issues", []):
                self.issues.add(f"#{number_of(str(ref))}" if number_of(str(ref)) else str(ref))
        for alias in aliases:
            for sha in self.facts.for_session(alias):
                self.add_commit(sha, "trailer", deep=False)
        for index, entry in enumerate(self.ledger):
            if isinstance(entry.get("session_id"), str) and any(same_session(a, entry["session_id"]) for a in aliases):
                self.add_ledger(index, "session")

    def run(self, run_id: str) -> None:
        for index, entry in enumerate(self.ledger):
            if str(entry.get("run_id")) == run_id or run_id in json.dumps(entry.get("references", {})):
                self.add_ledger(index, f"run {run_id}")
        data = gh_json(["run", "view", run_id, "--json", "headSha,workflowName,event,conclusion,url,displayTitle"]) if self.online else None
        if data and data.get("headSha"):
            self.notes.append(f"run {run_id}: {data.get('workflowName')} on {data.get('event')} ({data.get('conclusion')}) at {data['headSha'][:9]}")
            self.add_commit(data["headSha"], f"run {run_id}")
        elif not self.ledger_hits:
            self.gaps.append(f"run {run_id} not resolvable offline; pass --online (needs gh) or a provenance artifact")

    def finish(self) -> None:
        for session_id in self.session_via:
            if find_record(self.sessions, session_id) is None and session_id != HUMAN and not session_id.startswith(("github-actions:", "agentctl:")):
                self.gaps.append(f"session {session_id} is not registered in the session index")
        if not self.session_via and not self.gaps:
            self.gaps.append("no session linked to this reference")
        self.gaps = unique(self.gaps)

    def result(self, ref: str, kind: str) -> dict[str, Any]:
        self.finish()
        sessions = []
        for session_id, via in self.session_via.items():
            record = find_record(self.sessions, session_id) or {}
            sessions.append({
                "session_id": record.get("session_id", session_id), "harness": record.get("harness"),
                "provider": record.get("provider"), "status": record.get("status"),
                "started_at": record.get("started_at"), "summary": record.get("summary"),
                "issues": record.get("issues", []), "prs": record.get("prs", []),
                "related": record.get("related", []), "registered": bool(record), "via": sorted(via),
                "inferred": all(v.startswith("inferred") for v in via),
                "locators": [locate(i, record) for i in tuple(dict.fromkeys([record.get("session_id", session_id), *record.get("related", [])]))],
            })
        commits = [{k: c[k] for k in ("sha", "subject", "author", "date", "prs", "issues", "sessions", "via", "equivalents")}
                   for c in sorted(self.commits.values(), key=lambda c: c["date"], reverse=True)]
        why = [{"source": f"commit {c['sha'][:9]}", "text": strip_trailers(c["message"])[:800]} for c in self.commits.values()]
        why += [{"source": f"pr {pr}", "text": title} for pr, title in sorted(self.pr_titles.items())]
        why += [{"source": f"session {s['session_id']}", "text": s["summary"]} for s in sessions if s["summary"]]
        why += [{"source": f"ledger {e.get('timestamp') or e.get('date')}", "text": str(e.get("event", ""))[:600]}
                for _, e in sorted(self.ledger_hits.items())]
        candidates = sorted({str(p) for s in sessions if "trailer" in s["via"] for p in s["prs"]} - self.prs)
        return {"query": ref, "kind": kind, "commits": commits, "sessions": sessions, "candidate_prs": candidates,
                "prs": sorted(self.prs, key=lambda p: int(p[1:])), "issues": sorted(set(self.issues)),
                "ledger": [e for _, e in sorted(self.ledger_hits.items())], "why": why,
                "gaps": self.gaps, "notes": self.notes, "engine": getattr(self.facts, "engine", "direct")}


def strip_trailers(message: str) -> str:
    return "\n".join(line for line in message.splitlines() if not TRAILER_RE.match(line)).strip()


def trace(root: Path, ref: str, sessions: list[dict[str, Any]], ledger: list[dict[str, Any]], online: bool = False,
          facts: Any = None, infer: bool = False) -> dict[str, Any]:
    kind, value = classify(root, ref, sessions)
    tracer = Tracer(root, sessions, ledger, online, facts, infer)
    if kind == "line":
        path, line = value.rsplit(":", 1)
        out = run_git(root, "blame", "-L", f"{line},{line}", "--porcelain", "--", path)
        sha = out.split()[0] if out else ""
        if not sha or set(sha) == {"0"}:
            tracer.gaps.append(f"{value} is not committed (or git blame failed)")
        else:
            tracer.add_commit(sha, f"blame {value}")
    elif kind == "commit":
        if tracer.add_commit(value, "query") is None:
            tracer.notes.append(f"commit {value} is not in this repository (squashed/rebased away?); matching logs only")
            for index, entry in enumerate(ledger):
                if any(sha_match(value, str(c)) for c in row_shas(entry)):
                    tracer.add_ledger(index, f"commit {value[:9]}")
            for record in sessions:
                if any(sha_match(value, str(c)) for c in row_shas(record)):
                    tracer.add_session(record["session_id"], f"index:commit {value[:9]}")
                    for pr in record.get("prs", []):
                        tracer.pr(str(pr))
    elif kind == "pr":
        tracer.pr(value)
    elif kind == "issue":
        tracer.issue(value)
    elif kind == "number":
        tracer.pr(f"#{value}")
        tracer.issue(f"#{value}", force=False)
    elif kind == "session":
        tracer.session(value)
    elif kind == "run":
        tracer.run(value)
    return tracer.result(ref, kind)


def render_trace(result: Mapping[str, Any]) -> str:
    lines = [f"trace {result['query']}  ({result['kind']})"]
    if result["why"]:
        lines.append("\nWhy:")
        for item in result["why"]:
            text = " ".join(str(item["text"]).split())
            lines.append(f"  [{item['source']}] {text[:300]}")
    if result["sessions"]:
        lines.append("\nSessions:")
        for s in result["sessions"]:
            flag = ("" if s["registered"] else " (unregistered)") + (" (INFERRED, not evidence)" if s["inferred"] else "")
            lines.append(f"  {s['session_id']}{flag}  via {', '.join(s['via'])}")
            for loc in s.get("locators", []):
                if loc.get("open"):
                    where = f"  transcript: {loc['transcript']}" if loc.get("transcript") else ""
                    local = "local" if loc["available_locally"] else "not local"
                    lines.append(f"      open: {loc['open']}  [{local}]{where}")
    for title, key in (("Commits", "commits"),):
        if result[key]:
            lines.append(f"\n{title}:")
            for c in result[key]:
                lines.append(f"  {c['sha'][:9]} {c['subject']}  [{', '.join(c['sessions']) or 'no session trailer'}]")
                for eq in c.get("equivalents", []):
                    lines.append(f"      via rebase-equivalent {eq['recorded'][:7]} ({eq['kind']})")
    if result["prs"]:
        lines.append("\nPRs: " + ", ".join(result["prs"]))
    if result["candidate_prs"]:
        lines.append("PRs of these sessions (candidates): " + ", ".join(result["candidate_prs"]))
    if result["issues"]:
        lines.append("Issues: " + ", ".join(result["issues"]))
    if result["ledger"]:
        lines.append(f"Ledger events: {len(result['ledger'])} (use --json for full entries)")
    for note in result["notes"]:
        lines.append(f"note: {note}")
    for gap in result["gaps"]:
        lines.append(f"gap: {gap}")
    return "\n".join(lines)


# ---------------------------------------------------------------- PR check

def is_bot(name: str, email: str = "") -> bool:
    text = f"{name} {email}".lower()
    return "[bot]" in text or name.lower() in {"dependabot", "github-actions", "github-actions[bot]"}


def check_pr(root: Path, base: str, head: str, body: str = "", author: str = "",
             sessions: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    """Rebase merges drop the PR body, so ownership must live in the commits.

    Every non-bot commit needs an `Agent-Session:` trailer. The PR body may only
    declare `none (human)`, which exempts trailer-less (human) commits. Session
    IDs in the body are informational. Unknown trailer sessions only warn.
    """
    body_values = declared_sessions(body)
    human_body = HUMAN in body_values
    shas = (run_git(root, "rev-list", "--no-merges", f"{base}..{head}") or "").split()
    if run_git(root, "rev-parse", "--verify", "--quiet", f"{head}^{{commit}}") is None:
        raise ValueError(f"cannot resolve head {head!r}")
    commits, missing, warnings = [], [], []
    for sha in shas:
        info = commit_info(root, sha)
        if info is None:
            continue
        found = declared_sessions(info["message"])
        agent = [value for value in found if value != HUMAN]
        if is_bot(info["author"], info["email"]) or is_bot(author):
            status = "exempt-bot"
        elif found:
            status = "session" if agent else "human"
        else:
            status = "human-declared" if human_body else "missing"
        commits.append({"sha": sha, "subject": info["subject"], "sessions": found, "status": status})
        if status == "missing":
            missing.append(commits[-1])
        if sessions is not None:
            for value in agent:
                if find_record(sessions, value) is None and not value.startswith(("github-actions:", "agentctl:")):
                    warnings.append(f"{sha[:9]}: session {value} is not in the session index (run `agentctl sessions register` before pushing)")
    errors = []
    if missing:
        errors.append(
            f"{len(missing)} commit(s) have no '{TRAILER}: <harness>:<id>' trailer: "
            + ", ".join(c["sha"][:9] for c in missing[:5])
            + f". Agent commits get it from the hook (`make hooks`; amend/rebase to add it). "
            f"Human-only PRs: put '{TRAILER}: none (human)' in the PR body.")
    if human_body and any(c["status"] == "session" for c in commits):
        warnings.append("PR body declares 'none (human)' but some commits name agent sessions (mixed authorship)")
    if re.search(rf"(?im)^[ \t]*{TRAILER}:\s*<", body or "") and not body_values:
        warnings.append("PR body still contains the template placeholder for Agent-Session")
    return {"ok": not errors, "commits": commits, "declared_in_body": body_values, "errors": errors,
            "missing": [c["sha"] for c in missing], "warnings": warnings}


# ------------------------------------------------------------- provenance

def provenance(root: Path, env: Mapping[str, str], sessions: list[dict[str, Any]], ledger: list[dict[str, Any]],
               sha: str | None = None, pr: str | None = None, triggering_run: str | None = None) -> dict[str, Any]:
    sha = sha or env.get("GITHUB_SHA") or "HEAD"
    tracer = Tracer(root, sessions, ledger, online=False)
    info = tracer.add_commit(sha, "provenance")
    prs = [normalize_number_ref(pr, "pr")] if pr else []
    if info is None:
        tracer.gaps.append(f"commit {sha} is not in the checkout (shallow clone or PR head); sessions resolved from PR index records only")
    else:
        prs = unique(prs + info["prs"])
    for item in prs:
        tracer.pr(item, from_commit=True)
    tracer.finish()
    repo, run = env.get("GITHUB_REPOSITORY", ""), env.get("GITHUB_RUN_ID", "")
    return {
        "schema": "agent-provenance/1",
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "repository": repo, "workflow": env.get("GITHUB_WORKFLOW"), "job": env.get("GITHUB_JOB"),
        "event": env.get("GITHUB_EVENT_NAME"), "run_id": run, "run_attempt": env.get("GITHUB_RUN_ATTEMPT"),
        "run_url": f"{env.get('GITHUB_SERVER_URL', 'https://github.com')}/{repo}/actions/runs/{run}" if repo and run else None,
        "triggering_run_id": triggering_run or None,
        "commit": info["sha"] if info else sha, "subject": info["subject"] if info else None,
        "prs": prs, "issues": sorted(tracer.issues),
        "sessions": [{"session_id": s, "via": sorted(v)} for s, v in tracer.session_via.items()],
        "gaps": tracer.gaps,
    }


def render_provenance(value: Mapping[str, Any]) -> str:
    lines = [f"### Provenance: {value.get('workflow') or 'workflow'} run {value.get('run_id') or '?'}", "",
             f"- commit: `{value['commit']}` {value.get('subject') or ''}",
             f"- PRs: {', '.join(value['prs']) or 'none'}",
             f"- issues: {', '.join(value['issues']) or 'none'}",
             f"- sessions: {', '.join(s['session_id'] for s in value['sessions']) or 'none'}"]
    if value.get("triggering_run_id"):
        lines.append(f"- triggered by run: {value['triggering_run_id']}")
    lines += [f"- gap: {gap}" for gap in value["gaps"]]
    return "\n".join(lines) + "\n"
