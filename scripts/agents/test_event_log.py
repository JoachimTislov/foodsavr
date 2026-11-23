#!/usr/bin/env python3
"""Per-event repository logs (#397): writer, readers, validation, and conflict-free branches."""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CLI = HERE / "agentctl"
sys.path.insert(0, str(HERE))
import event_log as el  # noqa: E402


def load(name: str):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def clean_env(**extra: str) -> dict[str, str]:
    env = {k: v for k, v in os.environ.items() if not k.startswith(("GIT_", "AGENT_", "CLAUDE_CODE", "CODEX_", "T3CODE_"))}
    env.update({"GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null"})
    env.update(extra)
    return env


class EventFilesTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.dir = Path(self._tmp.name)

    def test_writes_one_sortable_line_per_event(self) -> None:
        early = el.write_event(self.dir, "ledger", {"timestamp": "2026-11-23T10:00:00+00:00", "event": "a"}, "t3-code:Abc_1",
                               datetime(2026, 11, 23, 10, 0, 0, 5, tzinfo=timezone.utc))
        late = el.write_event(self.dir, "ledger", {"timestamp": "2026-11-23T10:00:01+00:00", "event": "b"}, "t3-code:Abc_1",
                              datetime(2026, 11, 23, 10, 0, 1, tzinfo=timezone.utc))
        self.assertEqual(early.parent, self.dir / "2026" / "11")
        self.assertRegex(early.name, el.NAME_RE.pattern)
        self.assertTrue(early.name.startswith("20261123T100000000005Z-t3-code-abc-1-"))
        self.assertEqual(early.read_text().count("\n"), 1)
        self.assertEqual([row["event"] for row in el.read_events(self.dir)], ["a", "b"])
        self.assertEqual([row["event"] for row in el.read_events(self.dir, "sessions")], [])
        self.assertEqual(sorted(p.name for p in (self.dir / "2026/11").iterdir()), [early.name, late.name])

    def test_rejects_unknown_stream_and_non_finite_numbers(self) -> None:
        with self.assertRaises(ValueError):
            el.write_event(self.dir, "other", {})
        with self.assertRaises(ValueError):
            el.write_event(self.dir, "ledger", {"x": float("nan")})
        self.assertEqual(list(self.dir.rglob("*")), [])

    def test_human_events_get_a_slug(self) -> None:
        self.assertEqual(el.session_slug(None), "human")
        self.assertEqual(el.session_slug("github-actions:JoachimTislov/foodsavr/123/1"), "github-actions-joachimtislov-foodsavr-123-1")

    def test_validation_reports_format_and_field_errors(self) -> None:
        good = el.write_event(self.dir, "ledger", {"timestamp": "2026-11-23T10:00:00+00:00", "session_id": "human", "event": "x"})
        rel = Path(".agents/events") / good.relative_to(self.dir)
        self.assertEqual(el.event_errors(str(rel), good.read_text(), rel), [])
        bad_cases = {
            "two lines": good.read_text() * 2,
            "no newline": good.read_text().rstrip("\n"),
            "array": "[]\n",
            "no stream": '{"timestamp":"t","session_id":"s","event":"x"}\n',
            "no event": '{"stream":"ledger","timestamp":"t","session_id":"s"}\n',
            "session missing fields": '{"stream":"sessions","session_id":"a:b"}\n',
            "nan": '{"stream":"ledger","timestamp":NaN,"session_id":"s","event":"x"}\n',
        }
        for label, text in bad_cases.items():
            with self.subTest(label):
                self.assertTrue(el.event_errors(str(rel), text, rel))
        wrong_dir = Path(".agents/events/2025/01") / good.name
        self.assertTrue(el.event_errors(str(wrong_dir), good.read_text(), wrong_dir))
        self.assertTrue(el.event_errors("x", good.read_text(), Path(".agents/events/2026/11/bad-name.jsonl")))


class CheckLogsEventsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.logs = load("check_logs")
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)

    def test_validates_events_and_resolves_sessions_from_events(self) -> None:
        events = self.root / ".agents/events"
        session = el.write_event(events, "sessions", {
            "session_id": "t3-code:s-1", "provider": "claude", "harness": "t3-code", "started_at": "2026-11-23T10:00:00+00:00",
            "status": "active", "summary": "x"}, "t3-code:s-1")
        ledger = el.write_event(events, "ledger", {"timestamp": "2026-11-23T10:00:01+00:00", "session_id": "t3-code:s-1", "event": "did"}, "t3-code:s-1")
        names = [str(p.relative_to(self.root)) for p in (session, ledger)]
        self.assertEqual(self.logs.check(self.root, names), [])
        orphan = el.write_event(events, "ledger", {"timestamp": "2026-11-23T10:00:02+00:00", "session_id": "t3-code:unknown", "event": "did"})
        errors = self.logs.check(self.root, [str(orphan.relative_to(self.root))])
        self.assertTrue(any("not registered" in error for error in errors), errors)
        broken = events / "2026/11/20261123T100003000000Z-human-abcdef.jsonl"
        broken.write_text('{"stream":"ledger"}\n{"x":1}\n')
        self.assertTrue(self.logs.check(self.root, [str(broken.relative_to(self.root))]))
        stray = events / "2026/11/notes.txt"
        stray.write_text("x")
        self.assertTrue(any(".jsonl" in e for e in self.logs.check(self.root, [str(stray.relative_to(self.root))])))


class AgentctlEventsTest(unittest.TestCase):
    """The CLI writes events and reads legacy plus events; branches never conflict."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.dir = Path(self._tmp.name)
        self.repo = self.dir / "repo"
        self.repo.mkdir()
        self.legacy_ledger = self.dir / "legacy-ledger.jsonl"
        self.legacy_index = self.dir / "legacy-index.jsonl"
        self.git("init", "-q", "-b", "main")
        for key, value in (("user.email", "dev@example.com"), ("user.name", "Dev"), ("commit.gpgsign", "false")):
            self.git("config", key, value)
        (self.repo / "README").write_text("base\n")
        self.git("add", "README")
        self.git("commit", "-q", "-m", "base")

    def git(self, *args: str) -> str:
        return subprocess.run(["git", *args], cwd=self.repo, env=clean_env(), check=True, capture_output=True, text=True).stdout.strip()

    def cli(self, *args: str, session: str | None = None) -> str:
        env = clean_env(AGENT_EVENTS_DIR=str(self.repo / ".agents/events"), AGENT_KNOWLEDGE_DB=str(self.dir / "k.sqlite3"),
                        AGENT_EQUIVALENCE_CACHE=str(self.dir / "eq.json"),
                        AGENT_SESSION_INDEX=str(self.legacy_index), AGENT_LEDGER_FILE=str(self.legacy_ledger))
        if session:
            env["AGENT_SESSION_ID"] = session
        return subprocess.run([str(CLI), *args], cwd=ROOT, env=env, check=True, capture_output=True, text=True).stdout

    def log_work(self, session: str, name: str) -> None:
        self.cli("sessions", "register", "--provider", "claude", "--harness", "t3-code", "--summary", f"work {name}", session=session)
        self.cli("log", f"event {name}", session=session)
        (self.repo / name).write_text(name)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", f"change {name}")

    def test_register_and_log_write_events_and_leave_legacy_files_alone(self) -> None:
        self.legacy_index.write_text(json.dumps({"session_id": "t3-code:old", "provider": "claude", "harness": "t3-code",
                                                 "started_at": "2025-01-01T00:00:00+00:00", "status": "completed", "summary": "old"}) + "\n")
        self.legacy_ledger.write_text(json.dumps({"timestamp": "2025-01-01T00:00:00+00:00", "event": "legacy"}) + "\n")
        before = (self.legacy_index.read_bytes(), self.legacy_ledger.read_bytes())
        self.cli("sessions", "register", "--provider", "claude", "--harness", "t3-code", "--summary", "first", session="t3-code:new-1")
        self.cli("sessions", "register", "--summary", "second", "--status", "completed", session="t3-code:new-1")
        self.cli("log", "did something", session="t3-code:new-1")
        self.assertEqual((self.legacy_index.read_bytes(), self.legacy_ledger.read_bytes()), before)
        files = sorted((self.repo / ".agents/events").rglob("*.jsonl"))
        self.assertEqual(len(files), 3)
        self.assertEqual([json.loads(f.read_text())["stream"] for f in files].count("sessions"), 2)
        listed = {row["session_id"]: row for row in json.loads(self.cli("sessions", "list"))}
        self.assertEqual(set(listed), {"t3-code:old", "t3-code:new-1"})
        self.assertEqual((listed["t3-code:new-1"]["summary"], listed["t3-code:new-1"]["status"]), ("second", "completed"))
        self.assertNotIn("stream", listed["t3-code:new-1"])
        self.assertEqual(json.loads(self.cli("sessions", "commits", "t3-code:new-1"))["session"]["summary"], "second")

    def test_branches_that_log_events_rebase_without_conflict(self) -> None:
        self.git("checkout", "-q", "-b", "branch-a")
        self.log_work("t3-code:a-1", "a")
        self.git("checkout", "-q", "main")
        self.git("checkout", "-q", "-b", "branch-b")
        self.log_work("t3-code:b-1", "b")
        self.git("-c", "merge.union.driver=false", "rebase", "branch-a")  # no union driver: git would conflict on a shared file
        names = sorted(p.name for p in (self.repo / ".agents/events").rglob("*.jsonl"))
        self.assertEqual(len(names), 4)
        self.assertEqual(names, sorted(names))
        sessions = {row["session_id"] for row in json.loads(self.cli("sessions", "list"))}
        self.assertEqual(sessions, {"t3-code:a-1", "t3-code:b-1"})
        status = self.git("status", "--porcelain")
        self.assertEqual(status, "")


if __name__ == "__main__":
    unittest.main()
