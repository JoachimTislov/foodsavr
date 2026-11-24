#!/usr/bin/env python3
"""Focused tests for the dependency-free agent control plane."""

from __future__ import annotations

import json
import argparse
import contextlib
import importlib.util
import os
import re
import io
import sqlite3
import subprocess
import sys
import tempfile
import unittest
import urllib.error
from datetime import timedelta
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / "scripts/agents/agentctl"
WORKFLOW = ROOT / ".agents/workflows/repository-health.json"


def load_agentctl_module():
    spec = importlib.util.spec_from_file_location("agentctl_under_test", ROOT / "scripts/agents/agentctl.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def module_env() -> dict[str, str]:
    """The test process environment without hook-exported GIT_* variables."""
    return {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
def load_traceability_module():
    spec = importlib.util.spec_from_file_location("traceability_under_test", ROOT / "scripts/agents/traceability.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def load_trace_facts_module():
    spec = importlib.util.spec_from_file_location("trace_facts_under_test", ROOT / "scripts/agents/trace_facts.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def load_session_archive_module():
    spec = importlib.util.spec_from_file_location("session_archive_under_test", ROOT / "scripts/agents/session_archive.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class AgentctlTest(unittest.TestCase):
    def run_cli(self, *arguments: str, database: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
        env = {**module_env(), "AGENT_LEDGER_FILE": str(database.parent / "ledger.jsonl")}
        return subprocess.run(
            [str(CLI), "--database", str(database), *arguments],
            cwd=ROOT,
            env=env,
            check=check,
            capture_output=True,
            text=True,
        )

    def test_rebuild_and_query_include_todo(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "knowledge.sqlite3"
            result = self.run_cli("knowledge", "rebuild", database=database)
            self.assertGreater(json.loads(result.stdout)["documents"], 0)
            result = self.run_cli("query", "FoodSavr TODO", database=database)
            rows = json.loads(result.stdout)
            self.assertTrue(any(row["path"] == "TODO.md" for row in rows))

    def test_knowledge_rebuild_indexes_workflow_runs_and_events(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "knowledge.sqlite3"
            run_dir = Path(directory) / "runs" / "run-1"
            run_dir.mkdir(parents=True)
            result = {
                "workflow_id": "audit", "run_id": "run-1", "status": "succeeded",
                "started_at": "2026-01-01T00:00:00+00:00", "completed_at": "2026-01-01T00:01:00+00:00",
                "steps": [], "session_ids": [], "artifacts": [], "events": "events.jsonl", "usage": {}, "ledger_refs": [],
            }
            (run_dir / "result.json").write_text(json.dumps(result))
            (run_dir / "events.jsonl").write_text(json.dumps({"timestamp": "2026-01-01T00:00:01+00:00", "type": "run.started"}) + "\n")
            self.run_cli("knowledge", "rebuild", database=database)
            connection = module.connect(database)
            run = connection.execute("SELECT run_id, workflow_id, status FROM workflow_runs").fetchone()
            event = connection.execute("SELECT event_type FROM workflow_run_events").fetchone()
            connection.close()
            self.assertEqual(tuple(run), ("run-1", "audit", "succeeded"))
            self.assertEqual(event["event_type"], "run.started")
            context = json.loads(self.run_cli("context", "audit", "--limit", "2", database=database).stdout)
            self.assertEqual(context["runs"][0]["run_id"], "run-1")
            self.assertNotIn("raw_json", context["runs"][0])
            listed = json.loads(self.run_cli("runs", "list", "audit", database=database).stdout)
            self.assertEqual(listed[0]["run_id"], "run-1")
            self.assertEqual(listed[0]["events"][0]["event_type"], "run.started")
            self.assertNotIn("raw_json", listed[0])
            shown = json.loads(self.run_cli("runs", "show", "run-1", database=database).stdout)
            self.assertEqual(shown["workflow_id"], "audit")
            missing = self.run_cli("runs", "show", "missing", database=database, check=False)
            self.assertEqual(missing.returncode, 1)

            late_run_dir = database.parent / "runs" / "run-2"
            late_run_dir.mkdir(parents=True)
            late_result = {**result, "run_id": "run-2", "completed_at": "2026-01-01T00:02:00+00:00"}
            (late_run_dir / "result.json").write_text(json.dumps(late_result))
            (late_run_dir / "events.jsonl").write_text(json.dumps({"timestamp": "2026-01-01T00:02:01+00:00", "type": "run.completed"}) + "\n")
            refreshed = json.loads(self.run_cli("runs", "show", "run-2", database=database).stdout)
            self.assertEqual(refreshed["run_id"], "run-2")
            self.assertEqual(refreshed["events"][0]["event_type"], "run.completed")

            session_index = database.parent / "sessions.jsonl"
            session = {"session_id": "session-1", "provider": "fake", "harness": "test", "started_at": "2026-01-01T00:00:00+00:00", "status": "active", "summary": "first"}
            session_index.write_text(json.dumps(session) + "\n")
            with patch.object(module, "INDEX", session_index):
                module.rebuild(argparse.Namespace(database=str(database)), emit=False)
                session_index.write_text(json.dumps(session) + "\n" + json.dumps({**session, "session_id": "session-2", "summary": "second"}) + "\n")
                connection = module.fresh_catalog(database)
                session_count = connection.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
                connection.close()
            self.assertEqual(session_count, 2)

    def test_workflow_plan_is_dry_run(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_cli("workflow", "plan", str(WORKFLOW), database=Path(directory) / "db", check=False)
            plan = json.loads(result.stdout)
            self.assertIn(plan["status"], {"planned", "unavailable"})
            self.assertIn("no provider process was started", plan["execution"])
            self.assertEqual(len(plan["steps"]), 2)
            self.assertEqual(plan["references"]["issues"], ["#212", "#213"])
            self.assertTrue(all("capabilities" in step for step in plan["steps"]))
            self.assertTrue(all("failure_reasons" in capability for step in plan["steps"] for capability in step["capabilities"].values()))

    def test_workflow_prompt_carries_declared_orchestration_contract(self) -> None:
        module = load_agentctl_module()
        workflow = json.loads(WORKFLOW.read_text())
        workflow["context"]["skills"] = ["analysis"]
        workflow["limits"]["max_turns"] = 7
        workflow["outputs"] = {"result_schema": ".agents/workflows/result.schema.json"}
        step = {**workflow["steps"][0], "skills": ["research"]}
        prompt = module.workflow_prompt(workflow, step, "run-1", "context")
        self.assertIn('Skills: ["analysis", "research"]', prompt)
        self.assertIn('"max_turns": 7', prompt)
        self.assertIn("result.schema.json", prompt)

    def test_invalid_workflow_fails_validation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            invalid = Path(directory) / "invalid.json"
            invalid.write_text("{}")
            result = subprocess.run(
                [str(CLI), "workflow", "validate", str(invalid)],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn('"valid": false', result.stdout)

    def test_invalid_permissions_and_provider_fail_validation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            invalid = Path(directory) / "invalid.json"
            invalid.write_text(json.dumps({
                "schema_version": 1,
                "id": "Bad ID",
                "objective": "test",
                "steps": [{
                    "id": "one",
                    "role": "test",
                    "prompt": "test",
                    "providers": ["unknown"],
                    "acceptance": ["test"]
                }],
                "limits": {"max_attempts": True, "timeout_seconds": -1},
                "permissions": {"filesystem": "god-mode", "network": "full", "git": "push"}
            }))
            result = subprocess.run(
                [str(CLI), "workflow", "validate", str(invalid)],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("unknown provider", result.stdout)

    def test_write_capable_workflow_requires_isolated_worktree(self) -> None:
        module = load_agentctl_module()
        workflow = json.loads(WORKFLOW.read_text())
        workflow["permissions"]["filesystem"] = "workspace-write"
        path = Path(tempfile.mkdtemp()) / "write-workflow.json"
        path.write_text(json.dumps(workflow))
        errors = module.validate_workflow_file(path)
        self.assertTrue(any("require worktree.mode=isolated" in error for error in errors))
        workflow["worktree"] = {"mode": "isolated"}
        path.write_text(json.dumps(workflow))
        errors = module.validate_workflow_file(path)
        self.assertFalse(any("require worktree.mode=isolated" in error for error in errors))

    def test_acceptance_commands_cannot_bypass_policy(self) -> None:
        module = load_agentctl_module()
        permissions = {"network": "none", "git": "read-only", "github": "none"}
        errors = module.acceptance_command_errors("git push origin main", permissions)
        self.assertTrue(errors)
        self.assertTrue(any("mutating git" in error for error in errors))
        self.assertTrue(module.acceptance_command_errors("curl https://example.com", permissions))
        self.assertTrue(module.acceptance_command_errors("python3 -c 'open(\"x\", \"w\")'", permissions))
        allowlisted = {"network": "allowlisted", "git": "read-only", "github": "none"}
        self.assertFalse(module.acceptance_command_errors("curl https://github.com/status", allowlisted, ["github.com"]))
        self.assertTrue(module.acceptance_command_errors("curl https://evil.example/status", allowlisted, ["github.com"]))

    def test_acceptance_policy_can_be_explicitly_disabled(self) -> None:
        module = load_agentctl_module()
        pending = [{"criterion": "provider reports completion", "status": "pending"}]
        self.assertTrue(module.acceptance_satisfied(pending, required=False))
        self.assertFalse(module.acceptance_satisfied(pending, required=True))

    def test_workflow_context_cannot_escape_repository(self) -> None:
        module = load_agentctl_module()
        workflow = json.loads(WORKFLOW.read_text())
        workflow["context"]["files"] = ["../outside.txt"]
        errors = module.validate_workflow_file(WORKFLOW)
        self.assertFalse(any("escapes workspace" in error for error in errors))
        temporary = Path(tempfile.mkdtemp()) / "workflow.json"
        temporary.write_text(json.dumps(workflow))
        errors = module.validate_workflow_file(temporary)
        self.assertTrue(any("escapes workspace" in error for error in errors))

    def test_policy_compile_is_explicit_about_enforcement(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_cli("policy", "compile", "--provider", "vibe", database=Path(directory) / "db")
            projection = json.loads(result.stdout)
            self.assertFalse(projection["enforced"])
            self.assertTrue(projection["require_draft_pr"])
            self.assertIn("requested-permissions-not-enforced", projection["capability"]["failure_reasons"])

    def test_policy_compile_resolves_permission_modes_for_workspace_write(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            output = io.StringIO()
            with patch.dict(module.os.environ, {"AGENT_KNOWLEDGE_DB": str(Path(directory) / "db")}), \
                 patch.object(module, "version_for", return_value="2.1.326 (Claude Code)"), \
                 patch.object(module.shutil, "which", return_value="/usr/bin/claude"), \
                 contextlib.redirect_stdout(output):
                rc = module.policy_compile(argparse.Namespace(
                    provider="claude",
                    path=str(ROOT / ".agents/policies/agent-implement.json"),
                ))
            self.assertEqual(rc, 0)
            projection = json.loads(output.getvalue())
            self.assertEqual(projection["policy_id"], "agent-implement")
            self.assertTrue(projection["enforced"])
            self.assertTrue(projection["capability"]["permissions_enforced"])
            self.assertTrue(projection["capability"]["policy_safe"])

    def test_runner_configuration_can_be_overridden_by_trusted_environment(self) -> None:
        module = load_agentctl_module()
        with patch.dict(os.environ, {"AGENT_RUNNERS_FILE": "/tmp/runner-providers.json"}):
            self.assertEqual(module.configured_path("AGENT_RUNNERS_FILE", Path("default.json")), Path("/tmp/runner-providers.json"))

    def test_current_declarative_manifests_are_healthy(self) -> None:
        module = load_agentctl_module()
        self.assertEqual(module.validate_declarative_manifests(), [])

    def test_manifest_health_rejects_invalid_policy(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            policy = Path(directory) / "policy.json"
            policy.write_text(json.dumps({"schema_version": 1, "id": "broken", "filesystem": "unrestricted"}))
            with patch.object(module, "POLICY", policy):
                errors = module.validate_declarative_manifests()
        self.assertTrue(any("invalid filesystem" in error for error in errors))

    def test_manifest_health_rejects_invalid_provider_prompt_mode(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            runners = json.loads((ROOT / ".agents/runners/providers.json").read_text())
            runners["providers"]["fake"] = {"command": "fake", "headless": [], "prompt_mode": "unknown"}
            path = Path(directory) / "providers.json"
            path.write_text(json.dumps(runners))
            with patch.object(module, "RUNNERS", path):
                errors = module.validate_declarative_manifests()
        self.assertTrue(any("provider fake.prompt_mode is invalid" in error for error in errors))

    def test_workflow_run_fails_closed_on_manifest_drift(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            output = io.StringIO()
            with patch.object(module, "validate_declarative_manifests", return_value=["broken policy"]), contextlib.redirect_stdout(output):
                exit_code = module.workflow_run(argparse.Namespace(
                    path=str(WORKFLOW), provider="auto", execute=False,
                    database=str(Path(directory) / "knowledge.sqlite3"),
                ))
            self.assertEqual(exit_code, 1)
            result = json.loads(output.getvalue())
            self.assertEqual(result["reason"], "declarative manifest validation failed")

    def test_heal_reports_catalog_rebuild_failure(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            output = io.StringIO()
            with patch.object(module, "rebuild", side_effect=ValueError("catalog unavailable")), contextlib.redirect_stdout(output):
                exit_code = module.heal(argparse.Namespace(database=str(Path(directory) / "knowledge.sqlite3")))
            self.assertEqual(exit_code, 1)
            report = json.loads(output.getvalue())
            self.assertEqual(report["status"], "failed")
            self.assertIn("knowledge rebuild failed: catalog unavailable", report["errors"])

    def test_workflow_run_defaults_to_persisted_dry_run(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "db"
            output = io.StringIO()
            with patch.object(module, "append_ledger_event", return_value="ledger#dry-run"), contextlib.redirect_stdout(output):
                exit_code = module.workflow_run(argparse.Namespace(
                    path=str(WORKFLOW), provider="auto", execute=False, database=str(database),
                ))
            self.assertEqual(exit_code, 0)
            run = json.loads(output.getvalue())
            self.assertEqual(run["status"], "planned")
            self.assertEqual(len(run["steps"]), 2)
            self.assertEqual(run["ledger_refs"], ["ledger#dry-run"])
            self.assertIn('"type": "run.completed"', Path(run["events"]).read_text())
            self.assertTrue((database.parent / "runs" / run["run_id"] / "result.json").exists())

    def test_maintain_reports_the_requested_database(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "knowledge.sqlite3"
            index = Path(directory) / "sessions.jsonl"
            index.write_bytes((ROOT / ".agents/sessions/index.jsonl").read_bytes())
            with patch.dict(os.environ, {"AGENT_SESSION_INDEX": str(index)}):
                result = self.run_cli("maintain", database=database)
            report = json.loads(result.stdout)
            self.assertEqual(report["status"], "healthy")
            self.assertEqual(report["knowledge"], str(database))

    def test_health_rejects_corrupt_persisted_result(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            run_dir = Path(directory) / "runs" / "broken"
            run_dir.mkdir(parents=True)
            (run_dir / "result.json").write_text(json.dumps({"status": "not-a-result"}))
            errors = module.validate_run_artifacts(Path(directory) / "runs")
            with self.assertRaises(ValueError):
                module.fresh_catalog(Path(directory) / "knowledge.sqlite3")
        self.assertTrue(any("missing workflow_id" in error for error in errors))
        self.assertTrue(any("invalid status" in error for error in errors))

    def test_terminal_result_requires_completion_timestamp(self) -> None:
        module = load_agentctl_module()
        result = {
            "workflow_id": "audit", "run_id": "run-1", "status": "failed",
            "started_at": "2026-01-01T00:00:00+00:00", "steps": [], "session_ids": [],
            "artifacts": [], "events": "events.jsonl", "usage": {}, "ledger_refs": [],
        }
        self.assertIn("completed_at is required for terminal results", module.result_contract_errors(result))
        result["completed_at"] = ""
        self.assertIn("completed_at is required for terminal results", module.result_contract_errors(result))
        result["completed_at"] = "2026-01-01T00:01:00+00:00"
        result["session_ids"] = ["codex:session-1", "codex:session-1"]
        self.assertIn("session_ids must be unique", module.result_contract_errors(result))

    def test_heal_repairs_legacy_planned_result_defaults(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            run_dir = Path(directory) / "runs" / "legacy"
            run_dir.mkdir(parents=True)
            result_path = run_dir / "result.json"
            result_path.write_text(json.dumps({
                "workflow_id": "legacy", "run_id": "legacy-1", "status": "planned",
                "started_at": "2026-01-01T00:00:00+00:00", "steps": [], "session_ids": [],
                "artifacts": [], "ledger_refs": [],
            }))
            self.assertEqual(module.repair_legacy_run_artifacts(Path(directory) / "runs"), 1)
            repaired = json.loads(result_path.read_text())
            self.assertEqual(module.result_contract_errors(repaired), [])
            self.assertIn("run.completed", (run_dir / "events.jsonl").read_text())

    def test_heal_repairs_completion_timestamp_on_planned_result(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            run_dir = Path(directory) / "runs" / "legacy"
            run_dir.mkdir(parents=True)
            result_path = run_dir / "result.json"
            result_path.write_text(json.dumps({
                "workflow_id": "legacy", "run_id": "legacy-1", "status": "planned",
                "started_at": "2026-01-01T00:00:00+00:00", "steps": [], "session_ids": [],
                "artifacts": [], "events": "events.jsonl", "usage": {}, "ledger_refs": [],
            }))
            self.assertEqual(module.repair_legacy_run_artifacts(Path(directory) / "runs"), 1)
            repaired = json.loads(result_path.read_text())
            self.assertEqual(module.result_contract_errors(repaired), [])
            self.assertEqual(repaired["completed_at"], repaired["started_at"])

    def test_usage_uses_latest_snapshot_and_rejects_invalid_numbers(self) -> None:
        module = load_agentctl_module()
        output = "\n".join([
            json.dumps({"usage": {"input_tokens": 2, "output_tokens": 3, "total_tokens": 5}}),
            json.dumps({"usage": {"input_tokens": 4, "output_tokens": 6, "total_tokens": 10}}),
            json.dumps({"usage": {"input_tokens": -1, "output_tokens": float("nan")}}),
        ])
        self.assertEqual(module.extract_usage(output), {"input_tokens": 4, "output_tokens": 6, "total_tokens": 10})
        self.assertEqual(
            module.normalize_usage_totals({"input_tokens": 4, "output_tokens": 6}),
            {"input_tokens": 4, "output_tokens": 6, "total_tokens": 10},
        )

    def test_session_registration_upserts_duplicate_provider_sessions(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            index = Path(directory) / "sessions.jsonl"
            with patch.object(module, "INDEX", index):
                module.append_session_record("fake", "same", "run-1", "first", status="failed", attempt=1)
                module.append_session_record("fake", "same", "run-1", "second", status="succeeded", attempt=2, references={"issues": ["#213"], "prs": ["#236"]})
            records = [json.loads(line) for line in index.read_text().splitlines()]
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0]["status"], "succeeded")
            self.assertEqual(len(records[0]["attempts"]), 2)
            self.assertEqual(records[0]["issues"], ["#213"])
            self.assertEqual(records[0]["prs"], ["#236"])

    def test_log_writers_reject_legacy_paths_and_non_json_numbers(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(ValueError, "must use .jsonl"):
                module.append_event(root / "events.log", {"type": "test"})
            with self.assertRaisesRegex(ValueError, "must use .jsonl"):
                module.write_session_records(root / "index.md", [])
            index = root / "index.jsonl"
            index.write_text('{"existing":true}\n')
            with self.assertRaises(ValueError):
                module.write_session_records(index, [{"usage": float("nan")}])
            self.assertEqual(index.read_text(), '{"existing":true}\n')
            with self.assertRaises(ValueError):
                module.append_event(root / "events.jsonl", {"usage": float("inf")})
            self.assertEqual((root / "events.jsonl").read_text(), "")

    def test_ledger_and_session_references_are_preserved(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".agents").mkdir()
            (root / ".agents/ledger.jsonl").write_text('{"event":"existing"}\n')
            index = root / "sessions.jsonl"
            with patch.object(module, "ROOT", root), patch.object(module, "INDEX", index):
                module.append_session_record("fake", "session-1", "run-1", "summary", references={"issues": ["#212"], "prs": ["#236"]})
                module.append_ledger_event("run-1", "audit", "fake", "succeeded", references={"issues": ["#212"], "prs": ["#236|injected\nrow"]})
            session = json.loads(index.read_text())
            self.assertEqual(session["issues"], ["#212"])
            self.assertEqual(session["prs"], ["#236"])
            self.assertEqual((root / ".agents/ledger.jsonl").read_text(), '{"event":"existing"}\n')  # frozen legacy log
            (event_file,) = (root / ".agents/events").rglob("*.jsonl")
            event = json.loads(event_file.read_text())
            self.assertEqual(event["stream"], "ledger")
            self.assertEqual(event["references"], {"issues": ["#212"], "prs": ["#236|injected\nrow"]})
            self.assertEqual(len(event_file.read_text().splitlines()), 1)

    def test_context_exposes_session_references_without_transcript(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            index = root / "sessions.jsonl"
            index.write_text(json.dumps({
                "session_id": "codex:session-1", "provider": "codex", "harness": "codex",
                "started_at": "2026-01-01T00:00:00+00:00", "status": "succeeded",
                "summary": "FoodSavr status", "issues": ["#212"], "prs": ["#236"],
                "sources": ["https://example.com/source"], "commits": ["abc1234"],
            }) + "\n")
            database = root / "knowledge.sqlite3"
            with patch.object(module, "ROOT", ROOT), patch.object(module, "INDEX", index):
                module.rebuild(argparse.Namespace(database=str(database)), emit=False)
                output = io.StringIO()
                with patch.object(module, "DATABASE", database), contextlib.redirect_stdout(output):
                    module.context(argparse.Namespace(database=str(database), term="#212", limit=5))
            context = json.loads(output.getvalue())
            self.assertEqual(context["sessions"][0]["references"]["issue"], ["#212"])
            self.assertEqual(context["sessions"][0]["references"]["pr"], ["#236"])
            self.assertNotIn("transcript", context["sessions"][0])
            output = io.StringIO()
            with patch.object(module, "INDEX", index), contextlib.redirect_stdout(output):
                module.session_find(argparse.Namespace(database=str(database), term="#236", limit=5, provider=None))
            found = json.loads(output.getvalue())
            self.assertEqual(found[0]["session_id"], "codex:session-1")
            self.assertEqual(found[0]["references"]["pr"], ["#236"])
            self.assertNotIn("transcript", found[0])

    def test_heal_deduplicates_legacy_session_index(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            index = Path(directory) / "sessions.jsonl"
            duplicate = {"session_id": "codex:same", "provider": "codex", "status": "failed", "attempts": [{"attempt": 1}]}
            current = {"session_id": "codex:same", "provider": "codex", "status": "succeeded", "attempts": [{"attempt": 2}]}
            index.write_text("\n".join(json.dumps(item) for item in (duplicate, current)) + "\n")
            self.assertEqual(module.heal_session_index(index), 1)
            records = [json.loads(line) for line in index.read_text().splitlines()]
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0]["status"], "succeeded")
            self.assertEqual([item["attempt"] for item in records[0]["attempts"]], [1, 2])

    def test_heal_recovers_abandoned_running_artifact(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory, patch.object(module, "append_ledger_event", return_value="ledger#recovered"):
            run_dir = Path(directory) / "run-1"
            events = run_dir / "events.jsonl"
            events.parent.mkdir(parents=True)
            events.write_text("")
            result = {
                "workflow_id": "recovery-test", "run_id": "run-1", "status": "running",
                "started_at": "2026-01-01T00:00:00+00:00", "steps": [], "session_ids": [],
                "artifacts": ["events.jsonl"], "events": "events.jsonl", "usage": {}, "ledger_refs": [],
            }
            (run_dir / "result.json").write_text(json.dumps(result))
            self.assertEqual(module.recover_interrupted_runs(Path(directory)), 1)
            recovered = json.loads((run_dir / "result.json").read_text())
            self.assertEqual(recovered["status"], "failed")
            self.assertEqual(recovered["reason"], "interrupted-before-completion")
            self.assertIn('"type": "run.recovered"', events.read_text())

    def test_worktree_cleanup_is_bounded_to_run_directory(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            run_dir = Path(directory) / "run-1"
            (run_dir / "worktree").mkdir(parents=True)
            with patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
                self.assertIsNone(module.cleanup_isolated_worktree(run_dir))
            run.assert_called_once()
            self.assertEqual(run.call_args.args[0][:4], ["git", "worktree", "remove", "--force"])

    def test_workflow_cancel_terminalizes_run_and_rejects_path_traversal(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory, patch.object(module, "append_ledger_event", return_value="ledger#cancelled"):
            run_dir = Path(directory) / "runs" / "cancel-test"
            events = run_dir / "events.jsonl"
            events.parent.mkdir(parents=True)
            events.write_text("")
            result = {
                "workflow_id": "cancel-workflow", "run_id": "cancel-test", "status": "running",
                "started_at": "2026-01-01T00:00:00+00:00", "steps": [], "session_ids": [],
                "artifacts": ["events.jsonl"], "events": "events.jsonl", "usage": {}, "ledger_refs": [],
            }
            (run_dir / "result.json").write_text(json.dumps(result))
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(module.workflow_cancel(argparse.Namespace(run_id="cancel-test", database=str(Path(directory) / "knowledge.sqlite3"))), 0)
            self.assertEqual(json.loads((run_dir / "result.json").read_text())["status"], "cancelled")
            self.assertIn('"type": "run.cancelled"', events.read_text())
            with self.assertRaises(ValueError):
                module.workflow_cancel(argparse.Namespace(run_id="../escape", database=str(Path(directory) / "knowledge.sqlite3")))

    def test_isolated_workflow_propagates_execution_root(self) -> None:
        module = load_agentctl_module()
        workflow = {
            "schema_version": 1, "id": "isolated-test", "objective": "test isolated execution", "context": {},
            "worktree": {"mode": "isolated"},
            "steps": [{"id": "run", "role": "writer", "prompt": "write safely", "providers": ["fake"], "acceptance": ["command passes"], "acceptance_commands": ["true"]}],
            "limits": {"max_attempts": 1, "timeout_seconds": 5},
            "permissions": {"filesystem": "workspace-write", "network": "none", "git": "read-only", "github": "none"},
        }
        fake_specs = {"fake": {
            "command": "fake", "headless": [], "prompt_mode": "argument",
            "enforced_permissions": {"filesystem": ["workspace-write"], "network": ["none"], "git": ["read-only"], "github": ["none"]},
            "capability_verification": {"mode": "version-and-flags", "verified_version_prefix": "fake 1.", "required_flags": []},
        }}
        policy = {"schema_version": 1, "id": "write-policy", "filesystem": "workspace-write", "network": "none", "git": "read-only", "github": "none", "require_session_id": True}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            workflow_path = root / "workflow.json"
            policy_path = root / "policy.json"
            workflow_path.write_text(json.dumps(workflow))
            policy_path.write_text(json.dumps(policy))
            database = root / "knowledge.sqlite3"
            seen_cwds = []

            def fake_run(command, **kwargs):
                seen_cwds.append((command[0], kwargs.get("cwd")))
                if command[:3] == ["git", "rev-parse", "HEAD"]:
                    return subprocess.CompletedProcess(command, 0, stdout="base-sha\n", stderr="")
                if command[0] == "fake":
                    return subprocess.CompletedProcess(command, 0, stdout=json.dumps({"session_id": "isolated-session"}), stderr="")
                if command[:4] == ["git", "-C", str(kwargs.get("cwd")), "diff"]:
                    return subprocess.CompletedProcess(command, 0, stdout=b"", stderr=b"")
                return subprocess.CompletedProcess(command, 0, stdout="", stderr="")

            output = io.StringIO()
            with patch.object(module, "provider_specs", return_value=fake_specs), \
                 patch.object(module.shutil, "which", return_value="/usr/bin/fake"), \
                 patch.object(module, "version_for", return_value="fake 1.0"), \
                 patch.object(module.subprocess, "run", side_effect=fake_run), \
                 patch.object(module, "POLICY", policy_path), \
                 patch.object(module, "INDEX", root / "sessions.jsonl"), \
                 patch.object(module, "append_ledger_event", return_value="ledger#isolated"):
                with contextlib.redirect_stdout(output):
                    exit_code = module.workflow_run(argparse.Namespace(path=str(workflow_path), provider="auto", execute=True, database=str(database)))
            self.assertEqual(exit_code, 0)
            result = json.loads(output.getvalue())
            self.assertTrue(result["worktree"].endswith("/worktree"))
            patch_path = Path(result["patch"])
            self.assertTrue(patch_path.exists())
            self.assertEqual(patch_path.stat().st_mode & 0o777, 0o600)
            worktree_cwds = [cwd for command, cwd in seen_cwds if command in {"fake", "true"}]
            self.assertEqual(len(worktree_cwds), 2)
            self.assertEqual(worktree_cwds[0], worktree_cwds[1])
            self.assertTrue(str(worktree_cwds[0]).endswith("/worktree"))

    def test_workflow_execution_uses_quota_by_default_and_stops_when_exhausted(self) -> None:
        module = load_agentctl_module()
        workflow = json.loads((ROOT / ".agents/workflows/integrate-pr.json").read_text())
        workflow["steps"][0]["on_failure"] = "continue"
        future = module.hu.utc_now() + timedelta(hours=1)
        resets = [module.hu.iso_utc(future), module.hu.iso_utc(future + timedelta(hours=1))]
        quota = {
            name: module.hu.HarnessUsageSnapshot(name, "ok", (module.hu.UsageWindow("5h", "5h", 99, resets_at=reset),))
            for name, reset in zip(("codex", "claude"), resets)
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "workflow.json"
            path.write_text(json.dumps(workflow))
            output = io.StringIO()
            with patch.object(module, "available_providers", return_value=list(quota)), \
                 patch.object(module, "provider_is_safe", return_value=True), \
                 patch.object(module.hu, "probe_all", return_value=quota) as probe, \
                 patch.object(module, "resolve_workflow_context", return_value=""), \
                 patch.object(module, "provider_command") as command, \
                 patch.object(module, "append_ledger_event", return_value="ledger#quota") as ledger, \
                 contextlib.redirect_stdout(output):
                status = module.workflow_run(argparse.Namespace(
                    path=str(path), provider="auto", execute=True, database=str(root / "knowledge.sqlite3"),
                ))

            self.assertEqual(status, 0)
            result = json.loads(output.getvalue())
            self.assertEqual(len(result["steps"]), 1)
            self.assertEqual(result["status"], "unavailable")
            self.assertEqual(result["reason"], "quota-exhausted")
            self.assertEqual(result["failure_kind"], "quota_exhausted")
            self.assertEqual(result["resets_at"], resets[0])
            self.assertEqual(result["steps"][0]["route_reason"], "all-providers-quota-exhausted")
            probe.assert_called_once()
            command.assert_not_called()
            ledger.assert_called_once()
            self.assertEqual(ledger.call_args.kwargs["reason"], result["reason"])
            result_path = root / "runs" / result["run_id"] / "result.json"
            review = subprocess.run(
                [sys.executable, str(ROOT / "scripts/github/pr_review.py"), "record-review",
                 "--pr", "1", "--head-sha", "a" * 40, "--bot", "--no-record",
                 "--history", str(root / "history.jsonl"), "--workflow-result", str(result_path)],
                capture_output=True, text=True, check=True,
            )
            self.assertEqual(json.loads(review.stdout)["attestation_marker"]["status"], "skipped")

    def test_mid_run_quota_fails_over_or_preserves_partial_work(self) -> None:
        module = load_agentctl_module()
        workflow = {
            "schema_version": 1, "id": "quota-test", "objective": "exercise quota recovery", "context": {},
            "worktree": {"mode": "isolated"},
            "steps": [{
                "id": "run", "role": "writer", "prompt": "write safely", "providers": ["codex", "claude"],
                "acceptance": ["command passes"], "acceptance_commands": ["true"], "on_failure": "retry",
            }],
            "limits": {"max_attempts": 1, "timeout_seconds": 5},
            "permissions": {"filesystem": "workspace-write", "network": "none", "git": "read-only", "github": "none"},
        }
        first_reset = module.hu.utc_now() + timedelta(hours=1)
        last_reset = first_reset + timedelta(hours=1)
        quota = {
            name: module.hu.HarnessUsageSnapshot(name, "ok", (module.hu.UsageWindow("5h", "5h", used),))
            for name, used in (("codex", 10), ("claude", 20))
        }
        real_run = subprocess.run
        for all_exhausted in (False, True):
            with self.subTest(all_exhausted=all_exhausted), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                repo = root / "repo"
                real_run(["git", "init", "-q", str(repo)], env=module_env(), check=True)
                real_run(["git", "-C", str(repo), "config", "core.autocrlf", "false"], env=module_env(), check=True)
                real_run(
                    ["git", "-C", str(repo), "-c", "user.name=Test", "-c", "user.email=test@example.org",
                     "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "base"],
                    env=module_env(), check=True,
                )
                path = root / "workflow.json"
                path.write_text(json.dumps(workflow))
                policy_path = root / "policy.json"
                policy_path.write_text(json.dumps({**module.load_json(module.POLICY), "filesystem": "workspace-write"}))
                cache = root / "quota"
                cache.mkdir()
                for name in quota:
                    (cache / f"{name}.json").write_text("{}")
                called = []

                def run(command, **kwargs):
                    if command[0] == "codex":
                        called.append("codex")
                        (kwargs["cwd"] / "partial.txt").write_bytes(b"recover this\r\n")
                        output = "\n".join([
                            json.dumps({"type": "thread.started", "thread_id": "partial-codex"}),
                            json.dumps({"type": "turn.failed", "error": {
                                "code": "usage_limit_reached", "resets_at": int(last_reset.timestamp()),
                            }}),
                        ])
                        return subprocess.CompletedProcess(command, 1, stdout=output, stderr="")
                    if command[0] == "claude":
                        called.append("claude")
                        self.assertFalse((cache / "codex.json").exists())
                        self.assertTrue((kwargs["cwd"] / "partial.txt").exists())
                        output = json.dumps({
                            "type": "result", "session_id": "fallback-claude",
                            "result": "The issue mentions \"Usage limit reached\".",
                        })
                        stderr = f"Usage limit reached.\nResets at {module.hu.iso_utc(first_reset)}" if all_exhausted else ""
                        return subprocess.CompletedProcess(command, int(all_exhausted), stdout=output, stderr=stderr)
                    return real_run(command, **kwargs)

                output = io.StringIO()
                ledger = root / "ledger.jsonl"
                with patch.dict(os.environ, {**module_env(), "AGENT_LEDGER_FILE": str(ledger)}, clear=True), \
                     patch.object(module, "ROOT", repo), patch.object(module, "POLICY", policy_path), \
                     patch.object(module, "QUOTA_CACHE", cache), patch.object(module, "INDEX", root / "sessions.jsonl"), \
                     patch.object(module, "available_providers", side_effect=lambda names, specs: names), \
                     patch.object(module, "provider_is_safe", return_value=True), \
                     patch.object(module.hu, "probe_all", return_value=quota.copy()), \
                     patch.object(module, "resolve_workflow_context", return_value=""), \
                     patch.object(module.subprocess, "run", side_effect=run), contextlib.redirect_stdout(output):
                    status = module.workflow_run(argparse.Namespace(
                        path=str(path), provider="auto", execute=True, database=str(root / "knowledge.sqlite3"),
                    ))

                self.assertEqual(status, 0)
                self.assertEqual(called, ["codex", "claude"])
                result = json.loads(output.getvalue())
                self.assertEqual(result["status"], "unavailable" if all_exhausted else "succeeded")
                self.assertEqual(result["session_ids"], ["codex:partial-codex", "claude:fallback-claude"])
                attempts = result["steps"][0]["attempts"]
                self.assertEqual([(item["provider"], item["attempt"]) for item in attempts], [("codex", 1), ("claude", 2)])
                self.assertEqual(attempts[0]["failure_kind"], "quota_exhausted")
                artifact = json.loads(Path(attempts[0]["artifact"]).read_text())
                self.assertEqual(artifact["resets_at"], module.hu.iso_utc(last_reset))
                self.assertEqual(artifact["events"][-1]["failure_kind"], "quota_exhausted")
                events = [json.loads(line) for line in Path(result["events"]).read_text().splitlines()]
                self.assertTrue(any(event.get("failure_kind") == "quota_exhausted" for event in events))
                self.assertIn(b"+recover this\r\n", Path(result["patch"]).read_bytes())
                self.assertFalse(Path(result["worktree"]).exists())
                self.assertEqual(json.loads(ledger.read_text())["status"], result["status"])
                if all_exhausted:
                    self.assertEqual(result["reason"], "quota-exhausted")
                    self.assertEqual(result["resets_at"], module.hu.iso_utc(first_reset))
                    self.assertFalse((cache / "claude.json").exists())
                else:
                    self.assertTrue((cache / "claude.json").exists())

    def test_execute_retries_and_records_attempt_outcomes(self) -> None:
        module = load_agentctl_module()
        workflow = {
            "schema_version": 1,
            "id": "retry-test",
            "objective": "exercise recovery",
            "context": {},
            "steps": [{
                "id": "run",
                "role": "test",
                "prompt": "run the test",
                "providers": ["fake"],
                "acceptance": ["acceptance command passes"],
                "acceptance_commands": ["true"],
                "on_failure": "retry",
            }],
            "limits": {"max_attempts": 2, "timeout_seconds": 5},
            "permissions": {"filesystem": "read-only", "network": "none", "git": "read-only", "github": "none"},
        }
        fake_specs = {"fake": {
            "command": "fake", "headless": [], "prompt_mode": "argument",
            "enforced_permissions": {"filesystem": ["read-only"], "network": ["none"], "git": ["read-only"], "github": ["none"]},
            "capability_verification": {"mode": "version-and-flags", "verified_version_prefix": "fake 1.", "required_flags": []},
        }}
        with tempfile.TemporaryDirectory() as directory:
            directory_path = Path(directory)
            workflow_path = directory_path / "workflow.json"
            workflow_path.write_text(json.dumps(workflow))
            database = directory_path / "knowledge.sqlite3"
            index = directory_path / "sessions.jsonl"
            provider_attempt = 0

            def fake_run(command, **kwargs):
                nonlocal provider_attempt
                if command[0] == "fake":
                    provider_attempt += 1
                    return subprocess.CompletedProcess(
                        command, 1 if provider_attempt == 1 else 0,
                        stdout=json.dumps({"session_id": f"session-{provider_attempt}", "usage": {"input_tokens": provider_attempt * 2, "output_tokens": provider_attempt * 3}}), stderr="",
                    )
                return subprocess.CompletedProcess(command, 0, stdout="", stderr="")

            output = io.StringIO()
            with patch.object(module, "provider_specs", return_value=fake_specs), \
                 patch.object(module.shutil, "which", return_value="/usr/bin/fake"), \
                 patch.object(module, "version_for", return_value="fake 1.0"), \
                 patch.object(module.subprocess, "run", side_effect=fake_run), \
                 patch.object(module, "INDEX", index), \
                 patch.object(module, "append_ledger_event", return_value="ledger#retry-test"):
                with contextlib.redirect_stdout(output):
                    exit_code = module.workflow_run(argparse.Namespace(
                        path=str(workflow_path), provider="auto", execute=True, database=str(database),
                    ))

            self.assertEqual(exit_code, 0)
            result = json.loads(output.getvalue())
            self.assertEqual(result["status"], "succeeded")
            self.assertEqual(result["usage"]["total_tokens"], 15)
            self.assertEqual(result["steps"][0]["usage"]["total_tokens"], 15)
            events = Path(result["events"])
            self.assertTrue(events.exists())
            self.assertIn('"type": "run.completed"', events.read_text())
            self.assertIn('"type": "step.completed"', events.read_text())
            artifact = next(path for path in result["artifacts"] if path.endswith(".json") and path != result["events"])
            self.assertNotIn("raw_output", json.loads(Path(artifact).read_text()))
            self.assertEqual([attempt["status"] for attempt in result["steps"][0]["attempts"]], ["failed", "succeeded"])
            self.assertEqual(result["steps"][0]["route_reason"], "deterministic-fallback")
            records = [json.loads(line) for line in index.read_text().splitlines()]
            self.assertEqual([record["status"] for record in records], ["failed", "succeeded"])

    def test_execute_rejects_permissions_outside_policy(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            workflow_path = Path(directory) / "workflow.json"
            workflow = json.loads(WORKFLOW.read_text())
            workflow["id"] = "policy-test"
            workflow["permissions"]["network"] = "full"
            workflow_path.write_text(json.dumps(workflow))
            output = io.StringIO()
            with patch.object(module, "append_ledger_event", return_value="ledger#policy-test"), contextlib.redirect_stdout(output):
                exit_code = module.workflow_run(argparse.Namespace(
                    path=str(workflow_path), provider="codex", execute=True,
                    database=str(Path(directory) / "knowledge.sqlite3"),
                ))
            self.assertEqual(exit_code, 1)
            result = json.loads(output.getvalue())
            self.assertEqual(result["status"], "unavailable")
            self.assertIn("completed_at", result)
            self.assertEqual(result["ledger_refs"], ["ledger#policy-test"])
            self.assertIn('"type": "run.completed"', Path(result["events"]).read_text())

    def test_context_failure_terminalizes_started_run(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            workflow_path = Path(directory) / "workflow.json"
            workflow = json.loads(WORKFLOW.read_text())
            workflow["id"] = "context-failure"
            workflow_path.write_text(json.dumps(workflow))
            output = io.StringIO()
            with patch.object(module, "resolve_workflow_context", side_effect=ValueError("stale context")), \
                 patch.object(module, "append_ledger_event", return_value="ledger#context-failure"):
                with contextlib.redirect_stdout(output):
                    exit_code = module.workflow_run(argparse.Namespace(
                        path=str(workflow_path), provider="auto", execute=True,
                        database=str(Path(directory) / "knowledge.sqlite3"),
                    ))
            self.assertEqual(exit_code, 1)
            result = json.loads(output.getvalue())
            self.assertEqual(result["status"], "failed")
            self.assertEqual(result["reason"], "context-resolution-failed")
            self.assertIn('"type": "run.completed"', Path(result["events"]).read_text())

    def test_provider_flags_are_not_duplicated(self) -> None:
        module = load_agentctl_module()
        manifest = json.loads((ROOT / ".agents/runners/providers.json").read_text())["providers"]
        vibe_command, _ = module.provider_command("vibe", manifest["vibe"], "prompt")
        copilot_command, _ = module.provider_command("copilot", manifest["copilot"], "prompt")
        self.assertEqual(vibe_command.count("--prompt"), 1)
        self.assertEqual(copilot_command.count("--prompt"), 1)

    def test_claude_prompt_is_sent_on_stdin(self) -> None:
        # Deep-review prompts inline the PR diff and exceed Linux's 128 KiB per-argument limit.
        module = load_agentctl_module()
        manifest = json.loads((ROOT / ".agents/runners/providers.json").read_text())["providers"]
        prompt = "x" * 200_000
        for filesystem in ("read-only", "workspace-write"):
            spec = module.effective_spec(manifest["claude"], {"filesystem": filesystem})
            command, stdin = module.provider_command("claude", spec, prompt)
            self.assertEqual(stdin, prompt)
            self.assertNotIn(prompt, command)

    def test_antigravity_caps_the_utf8_prompt_argument(self) -> None:
        module = load_agentctl_module()
        spec = module.provider_specs()["antigravity"]
        prompt = "ø" * 65_535 + "a"
        command, stdin = module.provider_command("antigravity", spec, prompt)
        self.assertIsNone(stdin)
        self.assertEqual(command[-2:], ["--print", prompt])
        with self.assertRaisesRegex(ValueError, r"antigravity prompt is 131072 UTF-8 bytes.*131071"):
            module.provider_command("antigravity", spec, prompt + "a")

    def test_provider_artifact_classifies_structured_usage_errors(self) -> None:
        module = load_agentctl_module()
        reset = "2026-11-26T15:00:00Z"
        cases = {
            "antigravity": {"code": 429, "message": "Quota exceeded", "quotaResetTimeStamp": reset},
            "claude": {"type": "result", "is_error": True, "result": f"You've hit your limit. Resets at {reset}"},
        }
        with tempfile.TemporaryDirectory() as directory:
            for provider, payload in cases.items():
                with self.subTest(provider=provider):
                    path = Path(directory) / f"{provider}.json"
                    module.write_provider_artifact(path, provider, json.dumps(payload), 0, False, capture_verdict=True)
                    artifact = json.loads(path.read_text())
                    self.assertEqual(artifact["failure_kind"], "quota_exhausted")
                    self.assertEqual(artifact["resets_at"], reset)
                    self.assertNotIn("review_verdict", artifact)

    def test_provider_artifact_ignores_quota_quotes_in_model_output(self) -> None:
        module = load_agentctl_module()
        output = json.dumps({
            "type": "result", "is_error": True, "error": {"message": "invalid model requested"},
            "result": "The issue says usage limit reached.",
        }, indent=2)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "provider.json"
            module.write_provider_artifact(path, "claude", output + "\nunrelated diagnostic", 1, False)
            self.assertNotIn("failure_kind", json.loads(path.read_text()))

    def test_workflow_reports_oversized_antigravity_prompt_as_a_failed_attempt(self) -> None:
        module = load_agentctl_module()
        workflow = json.loads((ROOT / ".agents/workflows/integrate-pr.json").read_text())
        workflow["steps"] = [workflow["steps"][0]]
        workflow["steps"][0]["prompt"] = "ø" * 65_536
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "workflow.json"
            path.write_text(json.dumps(workflow))
            output = io.StringIO()
            with patch.object(module, "provider_is_safe", return_value=True), \
                 patch.object(module.hu, "probe_all", return_value={}), \
                 patch.object(module, "resolve_workflow_context", return_value=""), \
                 patch.object(module.subprocess, "run") as run, \
                 patch.object(module, "append_ledger_event", return_value="ledger#prompt-limit"), \
                 contextlib.redirect_stdout(output):
                status = module.workflow_run(argparse.Namespace(
                    path=str(path), provider="antigravity", execute=True, database=str(root / "knowledge.sqlite3"),
                ))
            run.assert_not_called()
            self.assertEqual(status, 1)
            attempt = json.loads(output.getvalue())["steps"][0]["attempts"][0]
            self.assertEqual(attempt["status"], "failed")
            self.assertRegex(attempt["error"], r"antigravity prompt is \d+ UTF-8 bytes, exceeding its 131071-byte argv limit")

    def test_router_plan_has_a_local_policy_safe_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_cli("router", "plan", str(WORKFLOW), database=Path(directory) / "db", check=False)
            plan = json.loads(result.stdout)
            self.assertEqual(plan["fallback"]["strategy"], "hybrid-deterministic-jev")
            self.assertFalse(plan["decision_provider"]["enabled"])
            self.assertEqual(len(plan["decisions"]), 2)

    def test_configured_router_is_bounded_and_validates_selection(self) -> None:
        module = load_agentctl_module()

        class Response:
            def __enter__(self):
                return self

            def __exit__(self, *_):
                return False

            def read(self, _limit):
                return json.dumps({"provider": "fake"}).encode()

        router = {"decision_provider": {
            "enabled": True, "base_url_env": "TEST_ROUTER_URL", "api_key_env": "TEST_ROUTER_KEY",
            "model_env": "TEST_ROUTER_MODEL", "timeout_ms": 500,
        }}
        workflow = {"id": "router-test", "permissions": {"filesystem": "read-only", "network": "allowlisted", "git": "read-only", "github": "none"}}
        step = {"id": "one"}
        with patch.dict(module.os.environ, {"TEST_ROUTER_URL": "https://router.example", "TEST_ROUTER_KEY": "secret", "TEST_ROUTER_MODEL": "auto"}), \
             patch.object(module.urllib.request, "urlopen", return_value=Response()) as urlopen:
            selected, reason = module.external_route(workflow, step, ["fake"], router, {"allow_hosts": ["router.example"]})
            self.assertEqual(selected, "fake")
            self.assertEqual(reason, "external-decision-provider")
            self.assertEqual(urlopen.call_args.kwargs["timeout"], 0.5)
            workflow["permissions"]["network"] = "none"
            urlopen.reset_mock()
            selected, reason = module.external_route(workflow, step, ["fake"], router)
            self.assertIsNone(selected)
            self.assertEqual(reason, "external-router-disabled-by-network-policy")
            urlopen.assert_not_called()

    def test_write_mode_is_selected_only_for_declared_enforcement(self) -> None:
        module = load_agentctl_module()
        manifest = json.loads((ROOT / ".agents/runners/providers.json").read_text())["providers"]
        write = {"filesystem": "workspace-write", "network": "none", "git": "read-only", "github": "none"}
        claude = module.effective_spec(manifest["claude"], write)
        self.assertIn("acceptEdits", claude["headless"])
        self.assertNotIn("plan", claude["headless"])
        self.assertEqual(["workspace-write"], claude["enforced_permissions"]["filesystem"])
        codex_command, _ = module.provider_command("codex", module.effective_spec(manifest["codex"], write), "prompt")
        self.assertIn("workspace-write", codex_command)
        read_only = {**write, "filesystem": "read-only"}
        self.assertIs(manifest["claude"], module.effective_spec(manifest["claude"], read_only))
        self.assertNotIn("permission_modes", manifest["gemini"])
        self.assertIs(manifest["gemini"], module.effective_spec(manifest["gemini"], write))
        with patch.object(module, "version_for", return_value="2.1.326 (Claude Code)"):
            self.assertTrue(module.capability_report("claude", claude, write)["permissions_enforced"])
            pushing = {**write, "git": "push"}
            self.assertFalse(module.capability_report("claude", module.effective_spec(manifest["claude"], pushing), pushing)["permissions_enforced"])

    def test_manifest_health_rejects_unenforced_permission_mode(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            runners = json.loads((ROOT / ".agents/runners/providers.json").read_text())
            runners["providers"]["claude"]["permission_modes"]["workspace-write"]["enforced_permissions"] = {}
            runners["providers"]["claude"]["permission_modes"]["workspace-write"]["capability_verification"]["required_flags"] = ["--missing"]
            path = Path(directory) / "providers.json"
            path.write_text(json.dumps(runners))
            with patch.object(module, "RUNNERS", path):
                errors = "\n".join(module.validate_declarative_manifests())
        self.assertIn("must declare enforcement of filesystem workspace-write", errors)
        self.assertIn("required_flags must be non-empty and present in the command", errors)

    def test_implement_workflow_is_unavailable_under_default_policy(self) -> None:
        module = load_agentctl_module()
        workflow = json.loads((ROOT / ".agents/workflows/implement-issue.json").read_text())
        default = json.loads((ROOT / ".agents/policies/default.json").read_text())
        implement = json.loads((ROOT / ".agents/policies/agent-implement.json").read_text())
        self.assertTrue(module.policy_errors(workflow, default))
        self.assertEqual([], module.policy_errors(workflow, implement))
        self.assertEqual([], module.validate_workflow_file(ROOT / ".agents/workflows/implement-issue.json"))

    def test_exported_patch_includes_new_files(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            # Git hooks export GIT_DIR/GIT_INDEX_FILE; never let them redirect these
            # commands into the surrounding checkout.
            env = module.isolated_git_env()
            repo, decoy = Path(directory) / "repo", Path(directory) / "decoy"
            git = ["git", "-C", str(repo), "-c", "user.name=t", "-c", "user.email=t@example.invalid"]
            for path in (repo, decoy):
                subprocess.run(["git", "init", "-q", str(path)], check=True, env=env)
            (repo / "tracked.txt").write_text("one\n")
            subprocess.run([*git, "add", "tracked.txt"], check=True, env=env)
            subprocess.run([*git, "commit", "-q", "-m", "base"], check=True, env=env)
            base = subprocess.run([*git, "rev-parse", "HEAD"], check=True, capture_output=True, text=True, env=env).stdout.strip()
            (repo / "tracked.txt").write_text("two\n")
            (repo / "new_test.dart").write_text("void main() {}\n")
            run_dir = Path(directory) / "run"
            run_dir.mkdir()
            hook_env = {"GIT_DIR": str(decoy / ".git"), "GIT_INDEX_FILE": str(decoy / ".git/index")}
            with patch.object(module, "path_reference", side_effect=str), patch.dict(os.environ, hook_env):
                module.export_worktree_changes(repo, base, run_dir)
            patch_text = (run_dir / "changes.patch").read_text()
            decoy_index = subprocess.run(["git", "-C", str(decoy), "ls-files"], capture_output=True, text=True, env=env).stdout
        self.assertIn("new_test.dart", patch_text)
        self.assertIn("+two", patch_text)
        self.assertEqual("", decoy_index)

    def test_human_scripts_follow_convention_and_are_blocked_for_agents(self) -> None:
        module = load_agentctl_module()
        self.assertIn("human-only", " ".join(module.acceptance_command_errors("scripts/human/github/create-agent-app.sh", {})))
        self.assertIn("human-only", " ".join(module.acceptance_command_errors("bash ./scripts/human/agents/login-claude-runner.sh", {})))
        guard = '[[ -t 0 && -t 1 ]] || { echo "scripts/human: interactive only; run it yourself in a terminal" >&2; exit 2; }'
        scripts = sorted((ROOT / "scripts/human").glob("**/*.sh"))
        self.assertTrue(scripts)
        for script in scripts:
            relative = script.relative_to(ROOT / "scripts/human")
            with self.subTest(script=str(relative)):
                self.assertEqual(2, len(relative.parts), "layout is <domain>/<intent>-<area>.sh")
                intent = relative.name.split("-", 1)[0]
                self.assertIn(intent, {"create", "login", "rotate", "sync", "revoke", "verify"})
                text = script.read_text(encoding="utf-8")
                for field in ("Intent", "Domain", "Area", "Secrets", "Why human"):
                    self.assertIn(f"# {field}:", text)
                self.assertIn(f"# Intent: {intent}", text)
                self.assertIn(f"# Domain: {relative.parts[0]}", text)
                self.assertIn("run_wizard() {\n" + guard, text)
                self.assertTrue(os.access(script, os.X_OK))
                subprocess.run(["bash", "-n", str(script)], check=True)
                completed = subprocess.run(["bash", str(script)], stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
                self.assertEqual(2, completed.returncode, completed.stderr)

    def test_wizard_library_is_shared_and_keeps_secrets_out_of_argv(self) -> None:
        template = (ROOT / ".agents/skills/wizard/template.sh").read_text(encoding="utf-8")
        library = template[: template.index("run_wizard() {")].split("\n", 1)[1]
        for script in sorted((ROOT / "scripts/human").glob("**/*.sh")):
            with self.subTest(script=str(script.relative_to(ROOT))):
                self.assertTrue(library + "run_wizard() {" in script.read_text(encoding="utf-8"),
                                "embed the current .agents/skills/wizard/template.sh library unchanged")
        with tempfile.TemporaryDirectory() as directory:
            stub = Path(directory) / "python3"
            record = Path(directory) / "record"
            stub.write_text(f'#!/bin/sh\nprintf "argv=%s\\nenv=%s\\n" "$*" "$NEW_DEMO_SECRET" > "{record}"\n')
            stub.chmod(0o755)
            env = {**module_env(), "PATH": f"{directory}:{os.environ['PATH']}"}
            runner = library + 'set_secret DEMO_SECRET "s3cr3t-value"\n'
            subprocess.run(["bash", "-c", runner], cwd=ROOT, env=env, check=True, capture_output=True, text=True)
            argv_line, env_line = record.read_text().splitlines()
        self.assertNotIn("s3cr3t-value", argv_line)
        self.assertIn("scripts/secrets/rotate.py DEMO_SECRET", argv_line)
        self.assertEqual("env=s3cr3t-value", env_line)
        agent_app_script = (ROOT / "scripts/human/github/create-agent-app.sh").read_text(encoding="utf-8")
        self.assertIn('set_var AGENT_APP_SLUG "$AGENT_APP_SLUG"', agent_app_script)
        self.assertIn('WRITTEN_VAR+=("$name")', library)
        self.assertIn('GitHub variable(s): ${WRITTEN_VAR[*]}', library)

    def test_session_commits_follow_agent_session_trailer(self) -> None:
        module = load_agentctl_module()
        args = argparse.Namespace(session_id="t3-code:a6d43689-90da-4199-95ca-abbb173cdecb", index=str(ROOT / ".agents/sessions/index.jsonl"))
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = module.session_commits(args)
        result = json.loads(output.getvalue())
        self.assertEqual(0, code)
        self.assertEqual(args.session_id, result["session"]["session_id"])

    def test_route_dataclasses_validate_and_roundtrip(self) -> None:
        module = load_agentctl_module()
        profile = module.WorkProfile(
            work_type=module.WorkType.IMPLEMENTATION,
            tier="code-specialist",
            reasoning_effort="high",
            signals=("role:implementer->implementation",),
            confidence=0.9,
        )
        self.assertEqual(profile.tier, module.ComplexityTier.CODE_SPECIALIST)
        self.assertEqual(module.WorkProfile.from_dict(profile.to_dict()), profile)
        self.assertIn("work_type", module.WorkProfile.json_schema()["properties"])

        with self.assertRaises(ValueError):
            module.WorkProfile(
                work_type="unknown-type",
                tier="fast",
                reasoning_effort="low",
                signals=("x",),
                confidence=0.5,
            )
        with self.assertRaises(ValueError):
            module.WorkProfile(
                work_type="triage",
                tier="fast",
                reasoning_effort="low",
                signals=(),
                confidence=1.5,
            )

        candidate = module.ModelCandidate(
            provider="codex",
            model="gpt-6.2-sol",
            tier="code-specialist",
            work_types=("implementation", "refactoring"),
            policy_safe=True,
            reasoning_effort="high",
        )
        self.assertEqual(module.ModelCandidate.from_dict(candidate.to_dict()), candidate)

        request = module.RouteRequest(
            workflow_id="wf-1",
            step_id="step-1",
            work_profile=profile,
            capabilities={"filesystem": "workspace-write"},
            candidates=(candidate,),
            available_providers=("codex",),
            available_models=("gpt-6.2-sol",),
        )
        self.assertEqual(module.RouteRequest.from_dict(request.to_dict()), request)

        decision = module.RouteDecision(
            provider="codex",
            model="gpt-6.2-sol",
            work_type="implementation",
            tier="code-specialist",
            reasoning_effort="high",
            confidence=0.92,
            rationale="Best code specialist fit.",
            source="router-local",
        )
        self.assertEqual(
            module.RouteDecision.from_dict(
                decision.to_dict(),
                allowed_providers={"codex"},
                allowed_models={"gpt-6.2-sol"},
            ),
            decision,
        )
        with self.assertRaises(ValueError):
            module.RouteDecision.from_dict(decision.to_dict(), allowed_providers={"claude"})
        with self.assertRaises(ValueError):
            module.RouteDecision.from_dict(decision.to_dict(), allowed_models={"claude-sonnet-5-5"})
        schema = module.RouteDecision.json_schema(["codex"], ["gpt-6.2-sol"])
        self.assertEqual(schema["properties"]["provider"]["enum"], ["codex"])
        self.assertEqual(schema["properties"]["model"]["enum"], ["gpt-6.2-sol"])

    def test_local_work_classifier_infers_all_work_types(self) -> None:
        module = load_agentctl_module()
        router = json.loads((ROOT / ".agents/runners/router.json").read_text())
        self.assertEqual(router["decision_provider"]["engine"], "typed-decision")
        self.assertEqual(router["decision_provider"]["base_url_env"], "ROUTER_BASE_URL")
        self.assertEqual(router["decision_provider"]["api_key_env"], "ROUTER_API_KEY")
        self.assertEqual(router["decision_provider"]["model_env"], "ROUTER_MODEL")
        cases = [
            ("triage", {"role": "triage-bot", "prompt": "Classify incoming issue"}, "read-only"),
            ("research", {"role": "researcher", "prompt": "Investigate package alternatives", "skills": ["research"]}, "read-only"),
            ("documentation", {"role": "docs-writer", "prompt": "Update README guide", "skills": ["docs-writer"]}, "read-only"),
            ("review", {"role": "reviewer", "prompt": "Review PR diff and inspect contracts", "skills": ["code-review"]}, "read-only"),
            ("testing", {"role": "qa-tester", "prompt": "Add unittest coverage", "skills": ["testing"]}, "read-only"),
            ("implementation", {"role": "implementer", "prompt": "Implement feature handler", "skills": ["creation"]}, "workspace-write"),
            ("refactoring", {"role": "refactor-lead", "prompt": "Refactor and deduplicate helper", "skills": ["maintenance"]}, "read-only"),
            ("architecture", {"role": "architect", "prompt": "Design ADR and data-model contract", "skills": ["codebase-design"]}, "read-only"),
            ("security", {"role": "security-auditor", "prompt": "Audit secret redaction and sandbox vulnerability"}, "read-only"),
        ]
        for expected_wt, step, fs in cases:
            workflow = {
                "id": "classify-test",
                "objective": step["prompt"],
                "permissions": {"filesystem": fs, "network": "none", "git": "read-only", "github": "none"},
            }
            profile = module.LocalWorkClassifier.classify(workflow, step, router)
            self.assertEqual(profile.work_type.value, expected_wt, msg=f"failed for {expected_wt}: {profile}")

        override_step = {
            "role": "generalist",
            "work_type": "security",
            "tier": "deep",
            "prompt": "Check release checklist",
        }
        profile = module.infer_work_profile(
            {"id": "override", "objective": "misc", "permissions": {"filesystem": "read-only"}},
            override_step,
            router,
        )
        self.assertEqual(profile.work_type, module.WorkType.SECURITY)
        self.assertEqual(profile.tier, module.ComplexityTier.DEEP)
        self.assertEqual(profile.confidence, 1.0)

    def test_select_local_model_route_and_provider_command_model_flag(self) -> None:
        module = load_agentctl_module()
        router = json.loads((ROOT / ".agents/runners/router.json").read_text())
        specs = json.loads((ROOT / ".agents/runners/providers.json").read_text())["providers"]
        workflow = {
            "id": "route-test",
            "objective": "Implement feature",
            "permissions": {"filesystem": "workspace-write", "network": "none", "git": "read-only", "github": "none"},
        }
        step = {"id": "impl", "role": "implementer", "prompt": "Write code"}
        decision, profile, reason = module.resolve_step_route(
            workflow, step, ["claude", "codex"], specs, router,
        )
        self.assertIsNotNone(decision)
        assert decision is not None
        self.assertEqual(decision.provider, "claude")
        self.assertEqual(decision.model, "claude-sonnet-5-5")
        self.assertEqual(profile.work_type, module.WorkType.IMPLEMENTATION)
        self.assertEqual(reason, "deterministic-fallback")

        codex_decision, _, _ = module.resolve_step_route(
            workflow, step, ["codex"], specs, router,
        )
        self.assertIsNotNone(codex_decision)
        assert codex_decision is not None
        self.assertEqual(codex_decision.provider, "codex")
        self.assertEqual(codex_decision.model, "gpt-6.2-sol")

        cmd, _ = module.provider_command("codex", specs["codex"], "hello", model="gpt-6.2-sol")
        self.assertEqual(cmd.count("--model"), 1)
        self.assertIn("gpt-6.2-sol", cmd)
        cmd_no_model, _ = module.provider_command("codex", specs["codex"], "hello")
        self.assertNotIn("--model", cmd_no_model)

    def test_external_route_sends_structured_schema_and_rejects_non_dict_json(self) -> None:
        module = load_agentctl_module()
        router = {
            "decision_provider": {
                "enabled": True,
                "engine": "typed-decision",
                "structured_output": True,
                "allow_control_plane_on_none": True,
                "timeout_ms": 500,
            }
        }
        specs = json.loads((ROOT / ".agents/runners/providers.json").read_text())["providers"]
        workflow = {
            "id": "router-structured",
            "objective": "Audit auth permissions",
            "permissions": {"filesystem": "read-only", "network": "none", "git": "read-only", "github": "none"},
        }
        step = {"id": "audit", "role": "security-auditor", "prompt": "Inspect auth checks"}
        captured_requests: list[dict[str, object]] = []

        class StructuredResponse:
            def __init__(self, body: object) -> None:
                self._body = body

            def __enter__(self):
                return self

            def __exit__(self, *_):
                return False

            def read(self, _limit):
                return json.dumps(self._body).encode()

        def fake_urlopen(req, **_kwargs):
            captured_requests.append(json.loads(req.data.decode()))
            return StructuredResponse({
                "choices": [{
                    "message": {
                        "content": json.dumps({
                            "provider": "claude",
                            "model": "claude-opus-5-5",
                            "work_type": "security",
                            "tier": "deep",
                            "reasoning_effort": "xhigh",
                            "confidence": 0.96,
                            "rationale": "Security audit needs deep reasoning.",
                            "source": "router-remote",
                        })
                    }
                }]
            })

        with patch.dict(module.os.environ, {"ROUTER_BASE_URL": "https://router.example", "ROUTER_API_KEY": "secret-key", "ROUTER_MODEL": "decision-1"}), \
             patch.object(module.urllib.request, "urlopen", side_effect=fake_urlopen):
            decision, reason = module.external_route_decision(
                workflow, step, ["codex", "claude"], router, specs=specs,
            )
        self.assertEqual(reason, "external-decision-provider")
        self.assertIsNotNone(decision)
        assert decision is not None
        self.assertEqual(decision.provider, "claude")
        self.assertEqual(decision.model, "claude-opus-5-5")
        self.assertEqual(captured_requests[0]["model"], "decision-1")
        self.assertEqual(
            captured_requests[0]["messages"][0]["content"],  # type: ignore[index]
            "You are a type-safe model-to-work routing decision engine. Return strictly valid JSON matching the schema.",
        )
        self.assertEqual(captured_requests[0]["response_format"]["type"], "json_schema")  # type: ignore[index]
        self.assertEqual(captured_requests[0]["response_format"]["json_schema"]["name"], "route_decision")  # type: ignore[index]
        self.assertTrue(captured_requests[0]["response_format"]["json_schema"]["strict"])  # type: ignore[index]

        for bad_payload in (
            [],
            "claude",
            123,
            {"choices": [{"message": {"content": "[]"}}]},
            {"provider": "not-safe"},
            {"provider": "claude", "model": "not-allowed-model", "work_type": "security", "tier": "deep", "reasoning_effort": "high", "confidence": 0.8, "rationale": "x", "source": "router-remote"},
        ):
            with self.subTest(bad_payload=bad_payload):
                with patch.dict(module.os.environ, {"ROUTER_BASE_URL": "https://router.example", "ROUTER_API_KEY": "secret-key"}), \
                     patch.object(module.urllib.request, "urlopen", return_value=StructuredResponse(bad_payload)):
                    rejected, reject_reason = module.external_route_decision(
                        workflow, step, ["codex", "claude"], router, specs=specs,
                    )
                self.assertIsNone(rejected)
                self.assertEqual(reject_reason, "external-router-returned-invalid-provider")

    def test_jev_auth_and_credit_failures_use_the_local_router(self) -> None:
        module = load_agentctl_module()
        router = module.load_json(module.ROUTER)
        router["decision_provider"].update(enabled=True, always_consult=True, allow_control_plane_on_none=True)
        workflow = {"id": "test", "objective": "Review documentation", "permissions": {"network": "none"}}
        step = {"id": "review", "role": "reviewer", "prompt": "Review the spec", "tier": "deep"}
        env = {"ROUTER_BASE_URL": "https://router.example", "ROUTER_API_KEY": "fixture"}
        for code in (401, 402, 429):
            with self.subTest(code=code), patch.dict(os.environ, env), patch.object(
                module.urllib.request, "urlopen",
                side_effect=urllib.error.HTTPError(env["ROUTER_BASE_URL"], code, "fixture", {}, None),
            ):
                decision, _, reason = module.resolve_step_route(
                    workflow, step, ["codex"], module.provider_specs(), router, quota_snapshots={},
                )
                self.assertEqual(decision.provider if decision else None, "codex")
                self.assertEqual(decision.model if decision else None, "gpt-6.1-terra")
                self.assertEqual(reason, f"external-router-http-{code}-using-local-routing")

    def test_router_matrix_decide_and_workflow_plan_expose_models(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            db = Path(directory) / "db"
            matrix_res = self.run_cli("router", "matrix", database=db)
            matrix = json.loads(matrix_res.stdout)
            self.assertEqual(set(matrix["work_types"]), {
                "triage", "research", "documentation", "review",
                "testing", "implementation", "refactoring", "architecture", "security",
            })
            self.assertIn("code-specialist", matrix["tiers"])
            self.assertIn("gemini-4-neon", matrix["providers"]["gemini"]["models"])

            decide_res = self.run_cli(
                "router", "decide", "--role", "architect", "--prompt", "Design ADR",
                database=db,
            )
            decided = json.loads(decide_res.stdout)
            self.assertEqual(decided["work_profile"]["work_type"], "architecture")
            self.assertEqual(decided["work_profile"]["tier"], "deep")
            self.assertTrue(decided["candidates"])

            plan_res = self.run_cli("workflow", "plan", str(WORKFLOW), database=db, check=False)
            plan = json.loads(plan_res.stdout)
            self.assertTrue(all("work_type" in step and "tier" in step and "selected_model" in step for step in plan["steps"]))

            run_res = self.run_cli("workflow", "run", str(WORKFLOW), "--model", "gemini-4-neon", database=db, check=False)
            run = json.loads(run_res.stdout)
            self.assertEqual(run["model"], "gemini-4-neon")
            self.assertEqual(run["status"], "planned")

    def test_workflow_validation_supports_work_type_tier_model_and_rejects_invalid(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            wf = json.loads(WORKFLOW.read_text())
            wf["steps"][0]["work_type"] = "review"
            wf["steps"][0]["tier"] = "deep"
            wf["steps"][0]["model"] = "claude-opus-5-5"
            valid_path = Path(directory) / "valid.json"
            valid_path.write_text(json.dumps(wf))
            self.assertEqual(module.validate_workflow_file(valid_path), [])

            wf["steps"][0]["work_type"] = "bogus-work-type"
            wf["steps"][0]["tier"] = "mega"
            invalid_path = Path(directory) / "invalid.json"
            invalid_path.write_text(json.dumps(wf))
            errors = "\n".join(module.validate_workflow_file(invalid_path))
            self.assertIn("invalid work_type", errors)
            self.assertIn("invalid tier", errors)

    def test_audit_fixes_sha_redaction_memoization_and_doc_api_exclusion(self) -> None:
        module = load_agentctl_module()
        # SHA_RE must reject pure alphabetic words like Feedbac/cceeded while keeping hex SHAs with digits
        self.assertIsNone(module.SHA_RE.search("Feedbac cceeded deadbeef"))
        self.assertIsNotNone(module.SHA_RE.search("commit a1b2c3d"))

        # document_paths must exclude doc/api
        for path in module.document_paths():
            parts = path.relative_to(ROOT).parts
            self.assertNotEqual(parts[:2], ("doc", "api"))

        # redacted_output must preserve HOME/PWD/PATH/XDG_* while redacting secret env vars
        with patch.dict(module.os.environ, {
            "HOME": "/home/runner/work/project",
            "XDG_CONFIG_HOME": "/home/runner/.config/xdg",
            "MY_PRIVATE_SIGNING_SECRET": "super-secret-value-1234",
        }):
            cleaned = module.redacted_output(
                "dir=/home/runner/work/project cfg=/home/runner/.config/xdg leak=super-secret-value-1234 token=abc123456"
            )
        self.assertIn("/home/runner/work/project", cleaned)
        self.assertIn("/home/runner/.config/xdg", cleaned)
        self.assertNotIn("super-secret-value-1234", cleaned)
        self.assertIn("token=[REDACTED]", cleaned)

        # version_for memoizes calls per (command, version_flags, PATH)
        module._VERSION_CACHE.clear()
        spec = {"command": "fake-cli", "version": ["--version"]}
        with patch.object(
            module.subprocess,
            "run",
            return_value=subprocess.CompletedProcess(["fake-cli", "--version"], 0, stdout="fake 1.2.3\n", stderr=""),
        ) as run_mock:
            first = module.version_for(spec)
            second = module.version_for(spec)
        self.assertEqual(first, "fake 1.2.3")
        self.assertEqual(second, "fake 1.2.3")
        self.assertEqual(run_mock.call_count, 1)

        # ensure_catalog validates byte sha256 and detects added/deleted docs
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            (tmp / "docs").mkdir()
            doc_a = tmp / "docs" / "a.md"
            doc_a.write_bytes(b"# A\n\xff\xfe\n")
            db = tmp / "state" / "knowledge.sqlite3"
            with patch.object(module, "ROOT", tmp), \
                 patch.object(module, "document_paths", return_value=[doc_a]), \
                 patch.object(module, "INDEX", tmp / "missing-sessions.jsonl"):
                module.rebuild(argparse.Namespace(database=str(db)), emit=False)
                conn = module.connect(db)
                module.ensure_catalog(conn, db)
                doc_b = tmp / "docs" / "b.md"
                doc_b.write_text("# B\n", encoding="utf-8")
                with patch.object(module, "document_paths", return_value=[doc_a, doc_b]):
                    with self.assertRaises(ValueError):
                        module.ensure_catalog(conn, db)
                with patch.object(module, "document_paths", return_value=[]):
                    with self.assertRaises(ValueError):
                        module.ensure_catalog(conn, db)
                conn.close()

    def test_router_status_and_configure_cli(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            db = tmp / "knowledge.sqlite3"
            override = tmp / "router.override.json"
            policy_out = tmp / "policy.json"
            env = {
                **module_env(),
                "AGENT_LEDGER_FILE": str(tmp / "ledger.jsonl"),
                "ROUTER_BASE_URL": "",
                "ROUTER_API_KEY": "",
                "ROUTER_MODEL": "",
            }
            status_res = subprocess.run(
                [str(CLI), "--database", str(db), "router", "status"],
                cwd=ROOT,
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )
            status = json.loads(status_res.stdout)
            self.assertEqual(status["effective_mode"], "local-deterministic")
            self.assertFalse(status["remote_ready"])
            self.assertFalse(status["router_override_active"])
            self.assertFalse(status["decision_provider"]["enabled"])

            cfg_res = subprocess.run(
                [
                    str(CLI), "--database", str(db),
                    "router", "configure",
                    "--enable",
                    "--allow-control-plane-on-none",
                    "--timeout-ms", "1200",
                    "--engine", "typed-decision",
                    "--allow-host", "https://router.example/v1",
                    "--policy-output", str(policy_out),
                    "--output", str(override),
                ],
                cwd=ROOT,
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )
            configured = json.loads(cfg_res.stdout)
            self.assertTrue(configured["valid"])
            self.assertTrue(configured["written"])
            self.assertTrue(configured["policy_updated"])
            self.assertTrue(configured["decision_provider"]["enabled"])
            self.assertTrue(configured["decision_provider"]["allow_control_plane_on_none"])
            self.assertEqual(configured["decision_provider"]["timeout_ms"], 1200)
            self.assertIn("router.example", configured["allow_hosts"])
            self.assertIn("router.example", json.loads(policy_out.read_text())["allow_hosts"])

            remote_env = {
                **env,
                "AGENT_ROUTER_FILE": str(override),
                "AGENT_POLICY_FILE": str(policy_out),
                "ROUTER_BASE_URL": "https://router.example/v1",
                "ROUTER_API_KEY": "super-secret-router-key-9876",
                "ROUTER_MODEL": "decision-model-1",
            }
            remote_status_res = subprocess.run(
                [str(CLI), "--database", str(db), "router", "status"],
                cwd=ROOT,
                env=remote_env,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertNotIn("super-secret-router-key-9876", remote_status_res.stdout)
            remote_status = json.loads(remote_status_res.stdout)
            self.assertEqual(remote_status["effective_mode"], "remote")
            self.assertTrue(remote_status["remote_ready"])
            self.assertTrue(remote_status["router_override_active"])
            self.assertTrue(remote_status["environment"]["ROUTER_API_KEY"]["set"])
            self.assertEqual(remote_status["environment"]["ROUTER_MODEL"]["value"], "decision-model-1")

            for bad_args in (
                ["--timeout-ms", "10", "--output", str(override)],
                ["--fallback-strategy", "bogus", "--output", str(override)],
                ["--allow-host", "   ", "--output", str(override)],
            ):
                bad = subprocess.run(
                    [str(CLI), "--database", str(db), "router", "configure", *bad_args],
                    cwd=ROOT,
                    env=env,
                    check=False,
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(bad.returncode, 1, bad_args)
                self.assertFalse(json.loads(bad.stdout)["valid"])

    def test_agent_router_setup_script_modes(self) -> None:
        script = ROOT / "scripts/setup/agent_router.sh"
        self.assertTrue(os.access(script, os.X_OK))
        subprocess.run(["bash", "-n", str(script)], check=True)

        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)
            env_file = tmp / ".env"
            override = tmp / "router.override.json"
            db = tmp / "knowledge.sqlite3"
            base_env = {
                **module_env(),
                "AGENT_ENV_FILE": str(env_file),
                "AGENT_KNOWLEDGE_DB": str(db),
                "AGENT_LEDGER_FILE": str(tmp / "ledger.jsonl"),
                "ROUTER_BASE_URL": "",
                "ROUTER_API_KEY": "",
                "ROUTER_MODEL": "",
            }

            check_res = subprocess.run(
                [str(script), "--check"],
                cwd=ROOT,
                env=base_env,
                stdin=subprocess.DEVNULL,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertIn("Router setup checks passed", check_res.stdout)

            local_res = subprocess.run(
                [str(script), "--local-only", "--override-file", str(override)],
                cwd=ROOT,
                env=base_env,
                stdin=subprocess.DEVNULL,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertIn("Router setup checks passed", local_res.stdout)
            self.assertFalse(json.loads(override.read_text())["decision_provider"]["enabled"])

            bad_url = subprocess.run(
                [
                    str(script),
                    "--enable-remote",
                    "--base-url", "http://insecure.example/v1",
                    "--model", "decision-1",
                    "--override-file", str(override),
                ],
                cwd=ROOT,
                env={**base_env, "ROUTER_API_KEY": "secret-val"},
                stdin=subprocess.DEVNULL,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(bad_url.returncode, 1)
            self.assertFalse(env_file.exists())

            remote_res = subprocess.run(
                [
                    str(script),
                    "--enable-remote",
                    "--base-url", "https://router.example/v1",
                    "--model", "decision-1",
                    "--timeout-ms", "900",
                    "--override-file", str(override),
                ],
                cwd=ROOT,
                env={**base_env, "ROUTER_API_KEY": "secret-router-test-val"},
                stdin=subprocess.DEVNULL,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertNotIn("secret-router-test-val", remote_res.stdout)
            self.assertTrue(env_file.exists())
            env_contents = env_file.read_text()
            self.assertIn("ROUTER_BASE_URL='https://router.example/v1'", env_contents)
            self.assertIn("ROUTER_MODEL='decision-1'", env_contents)
            self.assertIn("ROUTER_API_KEY='secret-router-test-val'", env_contents)
            override_json = json.loads(override.read_text())
            self.assertTrue(override_json["decision_provider"]["enabled"])
            self.assertTrue(override_json["decision_provider"]["allow_control_plane_on_none"])
            self.assertEqual(override_json["decision_provider"]["timeout_ms"], 900)

            recheck_res = subprocess.run(
                [str(script), "--check"],
                cwd=ROOT,
                env={**base_env, "AGENT_ROUTER_FILE": str(override)},
                stdin=subprocess.DEVNULL,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertNotIn("secret-router-test-val", recheck_res.stdout)
            self.assertIn("effective mode: remote", recheck_res.stdout)

            probe_missing_key = subprocess.run(
                [str(script), "--probe", "--base-url", "https://router.example/v1", "--model", "decision-1"],
                cwd=ROOT,
                env={**base_env, "AGENT_ENV_FILE": str(tmp / "empty.env")},
                stdin=subprocess.DEVNULL,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(probe_missing_key.returncode, 1)
            self.assertIn("ROUTER_API_KEY is not set", probe_missing_key.stdout)

            # Jev mode: --enable-remote without ROUTER_MODEL or --base-url defaults to https://api.typesafe.ai/v1/systemone
            jev_env_file = tmp / ".jev.env"
            jev_override = tmp / "router.jev.override.json"
            jev_res = subprocess.run(
                [
                    str(script),
                    "--enable-remote",
                    "--override-file", str(jev_override),
                ],
                cwd=ROOT,
                env={
                    **base_env,
                    "AGENT_ENV_FILE": str(jev_env_file),
                    "ROUTER_API_KEY": "dummy-router-key",
                },
                stdin=subprocess.DEVNULL,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertNotIn("dummy-router-key", jev_res.stdout)
            jev_env_contents = jev_env_file.read_text()
            self.assertIn("ROUTER_BASE_URL='https://api.typesafe.ai/v1/systemone'", jev_env_contents)
            self.assertIn("ROUTER_API_KEY='dummy-router-key'", jev_env_contents)
            self.assertNotIn("ROUTER_MODEL=", jev_env_contents)

    def test_hybrid_jev_routing_and_antigravity_provider(self) -> None:
        module = load_agentctl_module()
        # 1. resolve_router_endpoint_url
        self.assertEqual(
            module.resolve_router_endpoint_url("https://api.typesafe.ai/v1/systemone"),
            "https://api.typesafe.ai/v1/systemone",
        )
        self.assertEqual(
            module.resolve_router_endpoint_url("https://api.typesafe.ai/v1/systemone/"),
            "https://api.typesafe.ai/v1/systemone",
        )
        self.assertEqual(
            module.resolve_router_endpoint_url("https://api.example.com/v1"),
            "https://api.example.com/v1/chat/completions",
        )
        self.assertEqual(
            module.resolve_router_endpoint_url("https://api.example.com"),
            "https://api.example.com/chat/completions",
        )

        # 2. Antigravity (agy) provider command generation and conversation_id extraction
        specs = json.loads((ROOT / ".agents/runners/providers.json").read_text())["providers"]
        self.assertIn("antigravity", specs)
        agy_spec = specs["antigravity"]
        self.assertEqual(agy_spec["command"], "agy")
        read_perms = {"filesystem": "read-only", "network": "none", "git": "read-only", "github": "none"}
        write_perms = {"filesystem": "workspace-write", "network": "none", "git": "read-only", "github": "none"}
        agy_read_cmd, _ = module.provider_command(
            "antigravity",
            module.effective_spec(agy_spec, read_perms),
            "Audit repo",
            model="gemini-4-argon",
        )
        self.assertEqual(agy_read_cmd[0], "agy")
        self.assertIn("--mode", agy_read_cmd)
        self.assertIn("plan", agy_read_cmd)
        self.assertIn("--sandbox", agy_read_cmd)
        self.assertIn("--model", agy_read_cmd)
        self.assertIn("gemini-4-argon", agy_read_cmd)
        self.assertEqual(agy_read_cmd[-2:], ["--print", "Audit repo"])
        self.assertNotIn("-p", agy_read_cmd)

        agy_write_cmd, _ = module.provider_command(
            "antigravity",
            module.effective_spec(agy_spec, write_perms),
            "Implement issue",
            model="gemini-4-hydrogen",
        )
        self.assertIn("accept-edits", agy_write_cmd)
        self.assertIn("--dangerously-skip-permissions", agy_write_cmd)
        self.assertIn("gemini-4-hydrogen", agy_write_cmd)
        self.assertEqual(agy_write_cmd[-2:], ["--print", "Implement issue"])

        self.assertEqual(
            module.extract_session_id(json.dumps({"conversation_id": "conv-12345"})),
            "conv-12345",
        )
        self.assertEqual(
            module.extract_session_id(json.dumps({"result": {"conversationId": "conv-67890"}})),
            "conv-67890",
        )

        # 3. external_route_decision with Jev contract (no ROUTER_MODEL required)
        router = json.loads((ROOT / ".agents/runners/router.json").read_text())
        router["decision_provider"]["enabled"] = True
        router["decision_provider"]["allow_control_plane_on_none"] = True
        policy = json.loads((ROOT / ".agents/policies/default.json").read_text())
        self.assertIn("api.typesafe.ai", policy["allow_hosts"])
        workflow = {
            "id": "hybrid-test",
            "objective": "Handle ticket",
            "permissions": write_perms,
        }
        inferred_step = {"id": "step-1", "role": "worker", "prompt": "Apply change"}
        explicit_step = {"id": "explicit-impl", "role": "implementer", "work_type": "implementation", "prompt": "Build feature"}

        captured_reqs: list[tuple[str, dict[str, str], dict[str, object]]] = []

        class JevResponse:
            def __init__(self, payload: dict[str, object]) -> None:
                self._payload = payload

            def __enter__(self):
                return self

            def __exit__(self, *_):
                return False

            def read(self, _limit):
                return json.dumps(self._payload).encode()

        def fake_jev_urlopen(req, **_kwargs):
            headers = {k.lower(): v for k, v in req.header_items()}
            body = json.loads(req.data.decode())
            captured_reqs.append((req.full_url, headers, body))
            return JevResponse({
                "decision": {
                    "provider": "antigravity",
                    "model": "gemini-4-hydrogen",
                    "work_type": "implementation",
                    "tier": "code-specialist",
                    "effort": "high",
                    "confidence": 0.94,
                    "reason": "Jev selected Antigravity hydrogen for implementation.",
                }
            })

        with patch.dict(module.os.environ, {
            "ROUTER_BASE_URL": "https://api.typesafe.ai/v1/systemone",
            "ROUTER_API_KEY": "jev-token-xyz",
            "ROUTER_MODEL": "",
        }), patch.object(module.urllib.request, "urlopen", side_effect=fake_jev_urlopen):
            # Explicit work_type (confidence 1.0 >= 0.9) uses deterministic code without calling Jev
            det_decision, det_profile, det_reason = module.resolve_step_route(
                workflow, explicit_step, ["antigravity", "claude", "codex"], specs, router, policy,
            )
            self.assertEqual(len(captured_reqs), 0)
            self.assertEqual(det_reason, "hybrid-deterministic")
            self.assertIsNotNone(det_decision)
            assert det_decision is not None
            self.assertEqual(det_profile.confidence, 1.0)

            # Inferred step (confidence 0.85 < 0.9) calls Jev fallback without requiring ROUTER_MODEL
            jev_decision, jev_profile, jev_reason = module.resolve_step_route(
                workflow, inferred_step, ["antigravity", "claude", "codex"], specs, router, policy,
            )
            self.assertEqual(len(captured_reqs), 1)
            url, headers, body = captured_reqs[0]
            self.assertEqual(url, "https://api.typesafe.ai/v1/systemone")
            self.assertEqual(headers["authorization"], "Bearer jev-token-xyz")
            self.assertEqual(headers["content-type"], "application/json")
            self.assertNotIn("model", body)
            self.assertEqual(jev_reason, "external-decision-provider")
            self.assertIsNotNone(jev_decision)
            assert jev_decision is not None
            self.assertEqual(jev_decision.provider, "antigravity")
            self.assertEqual(jev_decision.model, "gemini-4-hydrogen")
            self.assertEqual(jev_decision.reasoning_effort, "high")
            self.assertEqual(jev_decision.rationale, "Jev selected Antigravity hydrogen for implementation.")

        # 4. Future model support: when ROUTER_MODEL is set, it is included in payload
        captured_reqs.clear()
        with patch.dict(module.os.environ, {
            "ROUTER_BASE_URL": "https://api.typesafe.ai/v1/systemone",
            "ROUTER_API_KEY": "jev-token-xyz",
            "ROUTER_MODEL": "future-router-v2",
        }), patch.object(module.urllib.request, "urlopen", side_effect=fake_jev_urlopen):
            module.external_route_decision(
                workflow, inferred_step, ["antigravity", "claude"], router, policy, specs=specs,
            )
            self.assertEqual(len(captured_reqs), 1)
            self.assertEqual(captured_reqs[0][2].get("model"), "future-router-v2")

    def test_review_artifact_persists_bounded_redacted_output_and_verdict(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory)

            # 1. Antigravity warning prefix + bold verdict + secret redaction
            agy_artifact = tmp / "agy.attempt-1.json"
            agy_stdout = (
                "warning: --mode plan has no effect while slash command expansion is disabled.\n"
                + json.dumps({
                    "conversation_id": "conv-agy-1",
                    "status": "SUCCESS",
                    "response": "## Standards\nClean code; bearer=secret-tok-999\n\n**VERDICT: APPROVE**",
                    "usage": {"input_tokens": 100, "output_tokens": 25},
                })
            )
            with patch.dict(module.os.environ, {"REVIEW_SECRET": "top-secret-env-value-1234"}):
                module.write_provider_artifact(
                    agy_artifact, "antigravity", agy_stdout, 0, False, capture_verdict=True,
                )
            agy_data = json.loads(agy_artifact.read_text())
            self.assertNotIn("raw_output", agy_data)
            self.assertEqual(agy_data["review_verdict"], "APPROVE")
            self.assertIn("## Standards", agy_data["review_output"])
            self.assertIn("bearer=[REDACTED]", agy_data["review_output"])
            self.assertNotIn("secret-tok-999", agy_data["review_output"])
            self.assertNotIn("--mode plan", agy_data["review_output"])

            # 2. Codex NDJSON keeps final agent_message and parses CHANGES_REQUESTED
            codex_artifact = tmp / "codex.attempt-1.json"
            codex_stdout = "\n".join([
                json.dumps({"type": "thread.started", "thread_id": "th-codex-1"}),
                json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": "Inspecting diff..."}}),
                json.dumps({
                    "type": "item.completed",
                    "item": {
                        "type": "agent_message",
                        "text": "## Standards\n- Fix null check in foo.py\n\nVERDICT: CHANGES_REQUESTED.",
                    },
                }),
            ])
            module.write_provider_artifact(
                codex_artifact, "codex", codex_stdout, 0, False, capture_verdict=True,
            )
            codex_data = json.loads(codex_artifact.read_text())
            self.assertEqual(codex_data["review_verdict"], "CHANGES_REQUESTED")
            self.assertIn("Fix null check in foo.py", codex_data["review_output"])
            self.assertNotIn("Inspecting diff...", codex_data["review_output"])

            # 3. Claude result and >16KB tail bounding with UTF-8 multi-byte characters and secret at boundary
            claude_artifact = tmp / "claude.attempt-1.json"
            padding = ("é" * 10000) + "\ntoken=boundary-leak-secret-xyz\n"
            final_tail = "\n## Spec\n- Missing edge case test\n\nVERDICT: CHANGES_REQUESTED"
            claude_stdout = json.dumps({
                "type": "result",
                "session_id": "cl-1",
                "result": padding + final_tail,
            })
            module.write_provider_artifact(
                claude_artifact, "claude", claude_stdout, 0, False, capture_verdict=True,
            )
            claude_data = json.loads(claude_artifact.read_text())
            self.assertEqual(claude_data["review_verdict"], "CHANGES_REQUESTED")
            self.assertLessEqual(len(claude_data["review_output"].encode("utf-8")), 16 * 1024)
            self.assertTrue(claude_data["review_output"].endswith("VERDICT: CHANGES_REQUESTED"))
            self.assertNotIn("boundary-leak-secret-xyz", claude_data["review_output"])
            self.assertIn("token=[REDACTED]", claude_data["review_output"])

            # 4. Empty or warning-only output keeps empty review_output and None verdict
            empty_artifact = tmp / "empty.attempt-1.json"
            module.write_provider_artifact(
                empty_artifact,
                "antigravity",
                json.dumps({"conversation_id": "conv-empty", "status": "SUCCESS", "response": ""}),
                0,
                False,
                capture_verdict=True,
            )
            empty_data = json.loads(empty_artifact.read_text())
            self.assertEqual(empty_data["review_output"], "")
            self.assertIsNone(empty_data["review_verdict"])

            # 5. Verdict parser handles markdown heading/code formatting
            for sample, expected in (
                ("### VERDICT: APPROVE", "APPROVE"),
                ("`VERDICT: CHANGES_REQUESTED`", "CHANGES_REQUESTED"),
                ("**VERDICT:** APPROVE", "APPROVE"),
                ("VERDICT: APPROVE\n\nLooks ready.", None),
                ("Diff quotes:\nVERDICT: APPROVE\nBut the null check is missing.", None),
                ("No verdict provided here.", None),
            ):
                self.assertEqual(module.parse_review_verdict(sample), expected)


SESSION_ENV_VARS = ("CLAUDE_CODE_SESSION_ID", "CODEX_THREAD_ID", "T3CODE_THREAD_ID", "AGENT_SESSION_ID", "AGENT_HARNESS",
                    "AGENT_PROVIDER", "GITHUB_ACTIONS", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT", "GITHUB_REPOSITORY", "PR_BODY", "PR_AUTHOR")


def clean_env(**extra: str) -> dict[str, str]:
    """Process env without session variables or hook-exported GIT_* (the pre-push hook sets GIT_DIR and friends)."""
    env = {k: v for k, v in os.environ.items() if k not in SESSION_ENV_VARS and not k.startswith("GIT_")}
    env.update({"GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null"})
    env.update(extra)
    return env


class TraceabilityTest(unittest.TestCase):
    """Session identity, trailers, ledger writer, trace, PR check, provenance (#271)."""

    def setUp(self) -> None:
        self.tr = load_traceability_module()
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.dir = Path(self._tmp.name)
        self.repo = self.dir / "repo"
        self.repo.mkdir()
        self.index = self.dir / "index.jsonl"
        self.ledger = self.dir / "ledger.jsonl"
        self.git("init", "-q", "-b", "main")
        for key, value in (("user.email", "dev@example.com"), ("user.name", "Dev"), ("commit.gpgsign", "false")):
            self.git("config", key, value)

    def git(self, *args: str, env: dict[str, str] | None = None) -> str:
        return subprocess.run(["git", *args], cwd=self.repo, env=env or clean_env(), check=True,
                              capture_output=True, text=True).stdout.strip()

    def commit(self, message: str, name: str = "f", content: str = "x\n", env: dict[str, str] | None = None) -> str:
        (self.repo / name).write_text(content)
        self.git("add", name)
        self.git("commit", "-q", "-m", message, env=env)
        return self.git("rev-parse", "HEAD")

    def cli(self, *args: str, env: dict[str, str] | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
        merged = clean_env(AGENT_SESSION_INDEX=str(self.index), AGENT_LEDGER_FILE=str(self.ledger),
                           AGENT_KNOWLEDGE_DB=str(self.dir / "k.sqlite3"))
        merged.update(env or {})
        return subprocess.run([str(CLI), *args], cwd=ROOT, env=merged, check=check, capture_output=True, text=True)

    def write_jsonl(self, path: Path, rows: list[dict]) -> None:
        path.write_text("".join(json.dumps(r) + "\n" for r in rows))

    # -- A. identity
    def test_detects_sessions_from_environment_table(self) -> None:
        tr = self.tr
        self.assertIsNone(tr.detect_session({}))
        wrapped = tr.detect_session({"CLAUDE_CODE_SESSION_ID": "abc-1", "T3CODE_THREAD_ID": "th-9"})
        self.assertEqual((wrapped.session_id, wrapped.harness, wrapped.provider), ("t3-code:th-9", "t3-code", "anthropic"))
        self.assertEqual(wrapped.related, ["claude-code:abc-1"])
        claude = tr.detect_session({"CLAUDE_CODE_SESSION_ID": "abc-1"})
        self.assertEqual((claude.session_id, claude.harness, claude.provider), ("claude-code:abc-1", "claude-code", "anthropic"))
        both = tr.detect_session({"CLAUDE_CODE_SESSION_ID": "abc-1", "CODEX_THREAD_ID": "019e"})
        self.assertEqual((both.session_id, both.related), ("claude-code:abc-1", ["codex:019e"]))
        self.assertEqual(tr.detect_session({"CODEX_THREAD_ID": "019e"}).session_id, "codex:019e")
        self.assertEqual(tr.detect_session({"T3CODE_THREAD_ID": "th-9"}).session_id, "t3-code:th-9")
        override = tr.detect_session({"AGENT_SESSION_ID": "vibe:s1", "T3CODE_THREAD_ID": "th-9", "CLAUDE_CODE_SESSION_ID": "abc-1"})
        self.assertEqual((override.session_id, override.related), ("vibe:s1", ["t3-code:th-9", "claude-code:abc-1"]))
        self.assertEqual(tr.detect_session({"AGENT_SESSION_ID": "bare", "AGENT_HARNESS": "mine"}).session_id, "mine:bare")
        actions = tr.detect_session({"GITHUB_ACTIONS": "true", "GITHUB_RUN_ID": "99", "GITHUB_REPOSITORY": "o/r"})
        self.assertEqual(actions.session_id, "github-actions:o/r/99/1")
        self.assertIsNone(tr.detect_session({"CLAUDE_CODE_SESSION_ID": "bad\nvalue"}))

    def test_legacy_ids_alias_to_canonical_ids(self) -> None:
        tr = self.tr
        self.assertTrue(tr.same_session("t3-code:01a1", "01a1"))
        self.assertTrue(tr.same_session("claude:01a1", "claude-code:01a1"))
        self.assertFalse(tr.same_session("claude-code:01a1", "claude-code:01a2"))
        record = tr.find_record([{"session_id": "01a1", "related": ["t3-code:th"]}], "codex:01a1")
        self.assertIsNotNone(record)
        self.assertIsNotNone(tr.find_record([{"session_id": "x:1", "related": ["t3-code:th"]}], "t3-code:th"))
        self.assertEqual(tr.normalize_session_id("None (human)"), "human")
        with self.assertRaises(ValueError):
            tr.normalize_session_id("bare")

    def test_ref_normalization_accepts_urls_and_numbers(self) -> None:
        tr = self.tr
        for raw in ("#269", "269", "PR 269", "https://github.com/o/r/pull/269"):
            self.assertEqual(tr.normalize_number_ref(raw, "pr", "o/r"), "#269")
        self.assertEqual(tr.normalize_number_ref("https://github.com/o/r/issues/5", "issue", "o/r"), "#5")
        foreign = "https://github.com/x/y/pull/3"
        self.assertEqual(tr.normalize_number_ref(foreign, "pr", "o/r"), foreign)
        with self.assertRaises(ValueError):
            tr.normalize_number_ref("soon", "pr")
        sha = self.commit("init")
        self.assertEqual(tr.normalize_commit(sha[:8], self.repo), sha)
        with self.assertRaises(ValueError):
            tr.normalize_commit("HEAD-ish", self.repo)

    def test_sessions_register_detects_identity_and_current_reports_it(self) -> None:
        env = {"CLAUDE_CODE_SESSION_ID": "abc-1", "T3CODE_THREAD_ID": "th-9"}
        root = ["--root", str(self.repo)]
        out = json.loads(self.cli("sessions", *root, "register", "--summary", "work", "--issue", "271", "--pr", "https://github.com/o/r/pull/7", env=env).stdout)
        self.assertEqual(out["session_id"], "t3-code:th-9")  # same convention as sessions on main
        self.assertEqual((out["issues"], out["prs"], out["related"], out["provider"]), (["#271"], ["#7"], ["claude-code:abc-1"], "anthropic"))
        self.cli("sessions", *root, "register", "--issue", "#272", env=env)
        rows = [json.loads(line) for line in self.index.read_text().splitlines()]
        self.assertGreater(len(rows), 1)  # appended, never rewritten
        rows = self.tr.fold_records(rows)
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0]["issues"], rows[0]["summary"]), (["#271", "#272"], "work"))
        current = json.loads(self.cli("sessions", *root, "current", env=env).stdout)
        self.assertEqual((current["session"]["session_id"], current["registered"]), ("t3-code:th-9", True))
        explicit = json.loads(self.cli("sessions", *root, "register", "--session-id", "vibe:s1", "--provider", "mistral", "--summary", "manual").stdout)
        self.assertEqual((explicit["harness"], explicit["provider"]), ("vibe", "mistral"))
        self.assertEqual(self.cli("sessions", *root, "current", check=False).returncode, 1)
        self.assertNotEqual(self.cli("sessions", *root, "register", check=False).returncode, 0)  # nothing detected, nothing given
        context = json.loads(self.cli("context", "work", env=env).stdout)
        self.assertEqual(context["current_session"]["session_id"], "t3-code:th-9")

    def test_trace_session_uses_the_shared_commit_by_trailer_lookup(self) -> None:
        module = load_agentctl_module()
        self.commit("chore: base")
        sha = self.commit("feat: tagged\n\nAgent-Session: t3-code:th-9", name="t.txt")
        rows = self.tr.session_commit_rows(self.repo, "t3-code:th-9")
        self.assertEqual([r["sha"] for r in rows], [sha])
        self.assertEqual(set(rows[0]), {"sha", "committed_at", "subject"})  # the shape `sessions commits` prints
        self.assertEqual([c["sha"] for c in self.traced("t3-code:th-9")["commits"]], [sha])
        self.assertEqual(self.tr.session_commit_rows(self.repo, "th-9")[0]["sha"], sha)  # legacy bare id

    # -- B. trailer hook
    def test_prepare_commit_msg_appends_trailer_only_with_a_session(self) -> None:
        message = self.dir / "msg"
        message.write_text("feat: x\n\nbody\n\nCo-Authored-By: A <a@b.c>\n\n# Please enter the commit message\n")
        self.assertFalse(self.tr.prepare_commit_msg(self.repo, str(message), "", {}))
        self.assertNotIn("Agent-Session", message.read_text())
        self.assertTrue(self.tr.prepare_commit_msg(self.repo, str(message), "", {"CLAUDE_CODE_SESSION_ID": "s1"}))
        text = message.read_text()
        self.assertEqual(self.tr.declared_sessions(text), ["claude-code:s1"])
        self.assertLess(text.index("Agent-Session"), text.index("# Please enter"))
        self.assertFalse(self.tr.prepare_commit_msg(self.repo, str(message), "", {"CLAUDE_CODE_SESSION_ID": "s1"}))
        self.assertEqual(text.count("Agent-Session"), message.read_text().count("Agent-Session"))
        self.assertFalse(self.tr.prepare_commit_msg(self.repo, str(self.dir / "missing"), "", {"CLAUDE_CODE_SESSION_ID": "s1"}))

    def test_prepare_commit_msg_merges_sessions_into_one_block_per_harness(self) -> None:
        message = self.dir / "msg"
        message.write_text("feat: x\n\nbody\n\nAgent-Session: claude-code:a\n\n# Please enter\n")
        for env in ({"CLAUDE_CODE_SESSION_ID": "b"}, {"CODEX_THREAD_ID": "c"}):
            self.assertTrue(self.tr.prepare_commit_msg(self.repo, str(message), "", env))
        text = message.read_text()
        self.assertEqual(text.count("Agent-Session"), 1)
        self.assertIn("  - claude-code: a, b\n  - codex: c\n", text)
        self.assertEqual(self.tr.declared_sessions(text), ["claude-code:a", "claude-code:b", "codex:c"])
        self.assertNotIn("Agent-Session", self.tr.strip_trailers(text))
        self.assertNotIn("claude-code: a", self.tr.strip_trailers(text))

    def test_tracked_hook_adds_trailer_and_never_blocks_humans(self) -> None:
        (self.repo / "scripts").mkdir()
        (self.repo / "scripts/agents").symlink_to(ROOT / "scripts/agents")
        shutil_hooks = self.repo / ".githooks"
        shutil_hooks.mkdir()
        hook = shutil_hooks / "prepare-commit-msg"
        hook.write_text((ROOT / ".githooks/prepare-commit-msg").read_text())
        hook.chmod(0o755)
        self.git("config", "core.hooksPath", ".githooks")  # what `make hooks` does
        status = self.tr.hooks_status(self.repo)
        self.assertTrue(status["installed"])
        agent = self.commit("feat: agent work", env=clean_env(CLAUDE_CODE_SESSION_ID="s1"), name="a")
        human = self.commit("fix: human work", name="b")
        self.assertEqual(self.tr.declared_sessions(self.git("log", "-1", "--format=%B", agent)), ["claude-code:s1"])
        self.assertEqual(self.tr.declared_sessions(self.git("log", "-1", "--format=%B", human)), [])

    # -- C. ledger writer and log validation
    def test_log_writes_session_id_canonical_refs_and_registers_session(self) -> None:
        sha = self.commit("init")
        env = {"CLAUDE_CODE_SESSION_ID": "abc-1"}
        args = ("log", "did a thing", "--root", str(self.repo), "--pr", "https://github.com/o/r/pull/7", "--issue", "271", "--commit", "HEAD", "--source", "https://example.com")
        entry = json.loads(self.cli(*args, env=env).stdout)
        self.assertEqual((entry["session_id"], entry["prs"], entry["issues"], entry["commits"]), ("claude-code:abc-1", ["#7"], ["#271"], [sha]))
        stored = json.loads(self.ledger.read_text())
        self.assertEqual(stored["session_id"], "claude-code:abc-1")
        self.assertTrue(self.ledger.read_text().endswith("\n"))
        self.assertEqual(json.loads(self.index.read_text())["prs"], ["#7"])
        human = json.loads(self.cli("log", "human event", "--human", "--root", str(self.repo)).stdout)
        self.assertEqual(human["session_id"], "human")
        failed = self.cli("log", "no session", "--root", str(self.repo), check=False)
        self.assertEqual(failed.returncode, 2)
        self.assertIn("no agent session", failed.stderr)
        bad = self.cli("log", "bad ref", "--root", str(self.repo), "--pr", "later", env=env, check=False)
        self.assertEqual(bad.returncode, 2)

    def test_check_logs_grandfathers_legacy_and_requires_session_on_new_events(self) -> None:
        spec = importlib.util.spec_from_file_location("check_logs_under_test", ROOT / "scripts/agents/check_logs.py")
        logs = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(logs)
        root = self.dir / "logs"
        (root / ".agents/sessions").mkdir(parents=True)
        legacy = [{"timestamp": "2026-11-20T10:00:00+00:00", "event": "old"}, {"date": "2026-10-01", "event": "older"}]
        new = "2026-11-22T10:00:00+00:00"
        self.write_jsonl(root / ".agents/sessions/index.jsonl", [
            {"session_id": "01a1-legacy", "started_at": "2026-11-20T00:00:00+00:00"},
            {"session_id": "claude-code:abc", "started_at": new}])

        def errors(rows: list[dict]) -> list[str]:
            self.write_jsonl(root / ".agents/ledger.jsonl", rows)
            return logs.check(root, [".agents/ledger.jsonl", ".agents/sessions/index.jsonl"])

        self.assertEqual(errors(legacy), [])
        self.assertEqual(errors([*legacy, {"timestamp": new, "event": "ok", "session_id": "claude-code:abc"}]), [])
        self.assertEqual(errors([*legacy, {"timestamp": new, "event": "ok", "session_id": "human"}]), [])
        self.assertEqual(errors([*legacy, {"timestamp": new, "event": "ok", "session_id": "github-actions:o/r/1/1"}]), [])
        self.assertTrue(any("needs `session_id`" in e for e in errors([{"timestamp": new, "event": "x"}])))
        self.assertTrue(any("not registered" in e for e in errors([{"timestamp": new, "event": "x", "session_id": "codex:nope"}])))
        self.assertTrue(any("invalid session_id" in e for e in errors([{"timestamp": new, "event": "x", "session_id": "nope"}])))
        self.assertTrue(any("ISO `timestamp`" in e for e in errors([{"date": new, "event": "x", "session_id": "human"}])))
        self.write_jsonl(root / ".agents/sessions/index.jsonl", [{"session_id": "bare-new", "started_at": new}])
        self.assertTrue(any("canonical" in e for e in logs.check(root, [".agents/sessions/index.jsonl"])))

    # -- D/E. trace
    def squash_fixture(self) -> dict[str, str]:
        base = self.commit("chore: base")
        squash = self.commit(
            "feat: add thing (#7)\n\n* feat: add thing\n\nAgent-Session: claude-code:abc-1\n\n* fix: tweak\n\nAgent-Session: codex:zzz\n\nCloses #271",
            name="thing.txt", content="line1\nline2\n")
        orphan = "deadbeefcafe0123456789abcdef0123456789ab"
        self.write_jsonl(self.index, [
            {"session_id": "claude-code:abc-1", "provider": "anthropic", "harness": "claude-code", "started_at": "2026-11-22T10:00:00+00:00",
             "status": "completed", "summary": "Build the thing", "issues": ["#271"], "prs": ["#7"], "commits": [orphan[:12]], "sources": []},
            {"session_id": "01a1legacy", "provider": "openai", "harness": "t3-code", "started_at": "2026-11-21T10:00:00+00:00",
             "status": "completed", "summary": "Legacy bare id", "issues": ["#271"], "prs": [], "commits": [], "sources": []},
            {"session_id": "claude-code:other", "provider": "anthropic", "harness": "claude-code", "started_at": "2026-11-22T11:00:00+00:00",
             "status": "active", "summary": "Unrelated", "issues": ["#9"], "prs": ["#8"], "commits": [], "sources": []}])
        self.write_jsonl(self.ledger, [
            {"timestamp": "2026-11-22T10:05:00+00:00", "session_id": "claude-code:abc-1", "event": "Opened PR 7", "prs": ["#7"]},
            {"timestamp": "2026-11-22T10:06:00+00:00", "session_id": "claude-code:other", "event": "other work", "prs": ["#8"]},
            {"timestamp": "2026-11-22T10:07:00+00:00", "session_id": "claude-code:abc-1", "event": "pre-squash commit", "commits": [orphan[:7]]},
            {"timestamp": "2026-11-22T10:08:00+00:00", "session_id": "agentctl:run-1", "type": "workflow.completed", "run_id": "run-1", "event": "run done"}])
        return {"base": base, "squash": squash, "orphan": orphan}

    def traced(self, ref: str) -> dict:
        return json.loads(self.cli("trace", ref, "--json", "--root", str(self.repo)).stdout)

    def test_trace_resolves_pr_to_squash_commit_trailers_and_why(self) -> None:
        refs = self.squash_fixture()
        for ref in ("#7", "https://github.com/o/r/pull/7", "pr:7"):
            result = self.traced(ref)
            self.assertEqual([c["sha"] for c in result["commits"]], [refs["squash"]])
            ids = {s["session_id"] for s in result["sessions"]}
            self.assertEqual(ids, {"claude-code:abc-1", "codex:zzz"})
            self.assertNotIn("claude-code:other", ids)
            self.assertIn("#271", result["issues"])
            self.assertTrue(any("Build the thing" in item["text"] for item in result["why"]))
            self.assertEqual([e["event"] for e in result["ledger"]], ["Opened PR 7"])
        self.assertTrue(any("codex:zzz" in gap for gap in self.traced("#7")["gaps"]))

    def test_trace_commit_blame_session_issue_and_legacy_alias(self) -> None:
        refs = self.squash_fixture()
        by_commit = self.traced(refs["squash"][:10])
        self.assertEqual(by_commit["kind"], "commit")
        self.assertIn("claude-code:abc-1", {s["session_id"] for s in by_commit["sessions"]})
        by_line = self.traced("thing.txt:2")
        self.assertEqual((by_line["kind"], by_line["commits"][0]["sha"]), ("line", refs["squash"]))
        by_session = self.traced("claude-code:abc-1")
        self.assertEqual(by_session["kind"], "session")
        self.assertEqual([c["sha"] for c in by_session["commits"]], [refs["squash"]])
        self.assertEqual(len(by_session["ledger"]), 2)
        by_issue = self.traced("issue:271")
        self.assertEqual({s["session_id"] for s in by_issue["sessions"]}, {"claude-code:abc-1", "01a1legacy", "codex:zzz"})
        by_legacy = self.traced("t3-code:01a1legacy")
        self.assertEqual(by_legacy["sessions"][0]["session_id"], "01a1legacy")
        text = self.cli("trace", "#7", "--root", str(self.repo)).stdout
        self.assertIn("Why:", text)
        self.assertIn("feat: add thing", text)

    def test_trace_finds_logs_for_commits_squashed_away_and_reports_gaps(self) -> None:
        refs = self.squash_fixture()
        orphan = self.traced(refs["orphan"][:9])
        self.assertIn("claude-code:abc-1", {s["session_id"] for s in orphan["sessions"]})
        self.assertEqual([c["sha"] for c in orphan["commits"]], [refs["squash"]])  # pre-squash SHA -> its PR's squash commit
        self.assertTrue(any("not in this repository" in n for n in orphan["notes"]))
        no_trailer = self.traced(refs["base"])
        self.assertTrue(any("no Agent-Session trailer" in g for g in no_trailer["gaps"]))
        run = self.traced("run:run-1")
        self.assertEqual(run["ledger"][0]["run_id"], "run-1")
        self.assertEqual(self.cli("trace", "nonsense words", "--root", str(self.repo), check=False).returncode, 2)

    def test_trace_resolves_rebase_merged_pr_without_subject_suffix(self) -> None:
        """This repo allows rebase merges only: commits keep messages, no (#N) in subjects."""
        self.commit("chore: base")
        first = self.commit("feat: one\n\nAgent-Session: claude-code:abc-1", name="a")
        second = self.commit("feat: two\n\nAgent-Session: claude-code:abc-1", name="b")
        self.commit("chore: unrelated", name="c")
        self.write_jsonl(self.index, [{"session_id": "claude-code:abc-1", "started_at": "2026-11-22T10:00:00+00:00", "status": "completed",
                                       "summary": "Rebased work", "issues": [], "prs": ["#7"], "commits": [], "sources": []}])
        self.write_jsonl(self.ledger, [])
        offline = self.traced("#7")
        self.assertEqual({c["sha"] for c in offline["commits"]}, {first, second})
        self.assertTrue(any("rebase merge" in n for n in offline["notes"]))
        by_commit = self.traced(second)
        self.assertEqual(by_commit["candidate_prs"], ["#7"])
        gh = {"title": "Two commits", "state": "MERGED", "body": "Agent-Session: claude-code:abc-1", "commits": [{}, {}], "mergeCommit": {"oid": second}}
        with patch.object(self.tr, "gh_json", return_value=gh):
            online = self.tr.trace(self.repo, "#7", self.tr.read_jsonl(self.index), [], online=True)
        self.assertEqual({c["sha"] for c in online["commits"]}, {first, second})
        self.assertTrue(any("Two commits" in item["text"] for item in online["why"]))

    def test_trace_online_enrichment_is_optional_and_time_bounded(self) -> None:
        self.squash_fixture()
        with patch.object(self.tr.shutil, "which", return_value=None):
            result = self.tr.trace(self.repo, "#7", self.tr.read_jsonl(self.index), self.tr.read_jsonl(self.ledger), online=True)
        self.assertTrue(any("gh enrichment unavailable" in n for n in result["notes"]))
        with patch.object(self.tr.shutil, "which", return_value="/bin/gh"), \
             patch.object(self.tr.subprocess, "run", side_effect=subprocess.TimeoutExpired("gh", 10)) as run:
            self.assertIsNone(self.tr.gh_json(["pr", "view", "7"]))
            self.assertEqual(run.call_args.kwargs["timeout"], 10)

    # -- F. PR check
    def check_pr(self, body: str = "", author: str = "") -> subprocess.CompletedProcess[str]:
        args = ["check-pr", "--root", str(self.repo), "--base", "main", "--head", "topic"]
        env = {"PR_BODY": body, "PR_AUTHOR": author}
        return self.cli(*args, env=env, check=False)

    def test_check_pr_requires_trailer_or_body_declaration_with_exemptions(self) -> None:
        self.commit("chore: base")
        self.git("checkout", "-q", "-b", "topic")
        self.commit("feat: agent", name="a", env=clean_env(), content="1\n")
        self.git("commit", "-q", "--amend", "-m", "feat: agent\n\nAgent-Session: claude-code:abc")
        self.commit("fix: human", name="b", content="2\n")
        failed = self.check_pr()
        self.assertEqual(failed.returncode, 1)
        self.assertEqual(len(json.loads(failed.stdout)["missing"]), 1)
        self.assertIn("::error::", failed.stderr)
        self.assertEqual(self.check_pr("Summary\nAgent-Session: none (human)\n").returncode, 0)
        informational = self.check_pr("Agent-Session: claude-code:abc\n")  # body session ids no longer exempt anything
        self.assertEqual(informational.returncode, 1)
        mixed = self.check_pr("Agent-Session: none (human)\n")
        self.assertIn("mixed authorship", mixed.stderr)
        self.assertIn("not in the session index", mixed.stderr)
        placeholder = self.check_pr("Agent-Session: <harness:session-id | none (human)>\n")
        self.assertEqual(placeholder.returncode, 1)
        self.assertIn("::warning::", placeholder.stderr)
        self.assertEqual(self.check_pr("Agent-Session: garbage value\n").returncode, 1)
        self.assertEqual(self.check_pr(author="dependabot[bot]").returncode, 0)
        self.git("commit", "-q", "--amend", "--author", "dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>", "--no-edit")
        self.assertEqual(self.check_pr().returncode, 0)

    # -- round 2: rebase equivalence, locators, projection, union-fold, coverage
    def rebased_fixture(self, amend: str) -> tuple[str, str]:
        """Commit A on a branch, move main, rebase A (optionally amended), fast-forward main. Returns (old, new)."""
        self.commit("chore: base")
        self.git("checkout", "-q", "-b", "feat")
        old = self.commit("feat: add a", name="a.txt", content="alpha\n")
        self.git("checkout", "-q", "main")
        self.commit("chore: main moved", name="m.txt")
        self.git("checkout", "-q", "feat")
        self.git("rebase", "-q", "main")
        if amend == "subject":
            self.git("commit", "-q", "--amend", "-m", "feat: add a (reworded)")
        elif amend == "content":
            (self.repo / "a.txt").write_text("alpha\nbeta\n")
            self.git("commit", "-q", "-a", "--amend", "--no-edit")
        self.git("checkout", "-q", "main")
        self.git("merge", "-q", "--ff-only", "feat")
        new = self.git("rev-parse", "HEAD")
        self.assertNotEqual(old, new)
        self.write_jsonl(self.index, [{"session_id": "claude-code:abc-1", "provider": "anthropic", "harness": "claude-code",
                                       "started_at": "2026-11-21T10:00:00+00:00", "status": "completed", "summary": "Add a",
                                       "issues": ["#5"], "prs": ["#7"], "commits": [old[:7]], "sources": []}])
        self.write_jsonl(self.ledger, [])
        return old, new

    def test_trace_maps_rebased_commit_to_recorded_sha_by_patch_id(self) -> None:
        old, new = self.rebased_fixture("subject")  # subject differs: only the patch-id can match
        result = self.traced(new)
        self.assertEqual(result["commits"][0]["equivalents"], [{"recorded": old[:7], "kind": "patch-id"}])
        self.assertEqual([s["session_id"] for s in result["sessions"]], ["claude-code:abc-1"])
        self.assertTrue(any(f"rebase-equivalent {old[:7]} (patch-id)" in v for v in result["sessions"][0]["via"]))
        self.assertIn("#7", result["prs"])
        self.assertIn(f"via rebase-equivalent {old[:7]} (patch-id)", self.cli("trace", new, "--root", str(self.repo)).stdout)
        self.assertTrue((self.dir / "equivalence.json").is_file(), "fingerprints are cached next to the projection")
        by_line = self.traced("a.txt:1")
        self.assertEqual(by_line["sessions"][0]["session_id"], "claude-code:abc-1")

    def test_trace_falls_back_to_author_date_email_subject_when_patch_differs(self) -> None:
        old, new = self.rebased_fixture("content")
        kinds = [eq["kind"] for eq in self.traced(new)["commits"][0]["equivalents"]]
        self.assertEqual(kinds, ["author-date+email+subject"])

    def test_unrelated_commits_are_not_equivalent(self) -> None:
        self.rebased_fixture("")
        other = self.commit("feat: unrelated", name="z.txt", content="zzz\n")
        result = self.traced(other)
        self.assertEqual(result["commits"][0]["equivalents"], [])
        self.assertEqual(result["sessions"], [])

    def test_online_commit_to_pr_lookup_uses_gh_api_with_timeout(self) -> None:
        self.commit("chore: base")
        sha = self.commit("feat: plain", name="p.txt")
        self.write_jsonl(self.index, [{"session_id": "claude-code:abc-1", "started_at": "2026-11-21T10:00:00+00:00", "summary": "Plain", "prs": ["#9"]}])
        calls = []

        def fake_gh(args: list[str], timeout: int = 10):
            calls.append(args)
            return [{"number": 9}] if args[0] == "api" else None

        with patch.object(self.tr, "gh_json", side_effect=fake_gh):
            result = self.tr.trace(self.repo, sha, self.tr.read_jsonl(self.index), [], online=True)
        self.assertTrue(calls[0][1].endswith(f"/commits/{sha}/pulls"))
        self.assertEqual([s["session_id"] for s in result["sessions"]], ["claude-code:abc-1"])
        self.assertIn("#9", result["prs"])

    # locators
    def test_locators_are_table_driven_and_report_only_paths(self) -> None:
        home = self.dir / "home"
        transcript = home / ".claude/projects/proj/abc-1.jsonl"
        transcript.parent.mkdir(parents=True)
        transcript.write_text("secret transcript body\n")
        found = self.tr.locate("claude-code:abc-1", home=home)
        self.assertEqual((found["open"], found["available_locally"], found["transcript"]), ("claude --resume abc-1", True, str(transcript)))
        self.assertNotIn("secret", json.dumps(found))
        missing = self.tr.locate("claude-code:nope", home=home)
        self.assertEqual((missing["open"], missing["available_locally"], missing["transcript"]), ("claude --resume nope", False, None))
        self.assertEqual(self.tr.locate("codex:019e", home=home)["open"], "codex resume 019e")
        self.assertIn("thread th-9", self.tr.locate("t3-code:th-9", home=home)["open"])
        actions = self.tr.locate("github-actions:o/r/123/2")
        self.assertEqual((actions["open"], actions["available_locally"]), ("https://github.com/o/r/actions/runs/123/attempts/2", False))
        self.assertEqual(self.tr.locate("claude:abc-1", home=home)["harness"], "claude-code")  # legacy prefix alias
        self.assertEqual(self.tr.locate("01a1legacy", {"harness": "t3-code"}, home=home)["harness"], "t3-code")
        self.assertIsNone(self.tr.locate("mystery:1", home=home)["open"])
        self.squash_fixture()
        sessions = self.traced("claude-code:abc-1")["sessions"]
        self.assertEqual(sessions[0]["locators"][0]["open"], "claude --resume abc-1")
        self.assertIn("open: claude --resume abc-1", self.cli("trace", "claude-code:abc-1", "--root", str(self.repo)).stdout)

    # union-merge friendly index
    def test_duplicate_index_lines_fold_and_writers_only_append(self) -> None:
        module = load_agentctl_module()
        rows = [{"session_id": "a:1", "status": "active", "issues": ["#1"], "attempts": [{"attempt": 1}], "summary": "first"},
                {"session_id": "b:2", "status": "active"},
                {"session_id": "a:1", "status": "completed", "issues": ["#2", "#1"], "attempts": [{"attempt": 1}, {"attempt": 2}]}]
        folded = self.tr.fold_records(rows)
        self.assertEqual([r["session_id"] for r in folded], ["a:1", "b:2"])
        self.assertEqual((folded[0]["status"], folded[0]["issues"], folded[0]["summary"]), ("completed", ["#1", "#2"], "first"))
        self.assertEqual(folded[0]["attempts"], [{"attempt": 1}, {"attempt": 2}])
        self.write_jsonl(self.index, rows)
        self.assertEqual(len(module.records(self.index)), 2)
        self.assertEqual(len(module.records(self.index, fold=False)), 3)
        identity = self.tr.Identity("a:1", "a", "unknown", [], "test")
        before = self.index.read_text()
        module.ensure_session(self.index, identity)  # nothing new: no write
        self.assertEqual(self.index.read_text(), before)
        module.ensure_session(self.index, identity, prs=["#7"])
        self.assertTrue(self.index.read_text().startswith(before))  # appended
        self.assertEqual(module.records(self.index)[0]["prs"], ["#7"])
        self.assertEqual(module.heal_session_index(self.index), 2)  # `maintain`/`heal` compact: 4 lines -> 2
        self.assertEqual(len(self.index.read_text().splitlines()), 2)

    def test_check_logs_accepts_duplicate_index_lines_and_gitattributes_declare_union(self) -> None:
        spec = importlib.util.spec_from_file_location("check_logs_dupes", ROOT / "scripts/agents/check_logs.py")
        logs = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(logs)
        root = self.dir / "dupes"
        (root / ".agents/sessions").mkdir(parents=True)
        new = "2026-11-22T10:00:00+00:00"
        self.write_jsonl(root / ".agents/sessions/index.jsonl", [
            {"session_id": "claude-code:a", "started_at": new, "prs": ["#1"]}, {"session_id": "claude-code:a", "started_at": new, "prs": ["#2"]}])
        self.assertEqual(logs.check(root, [".agents/sessions/index.jsonl"]), [])
        attributes = (ROOT / ".gitattributes").read_text()
        for log in (".agents/ledger.jsonl", ".agents/sessions/index.jsonl", "specs/source-of-truth/sync-ledger.jsonl"):
            self.assertIn(f"{log} merge=union", attributes)

    # projection
    def test_projection_serves_trace_when_fresh_and_goes_stale_on_change(self) -> None:
        module = load_agentctl_module()
        facts_module = load_trace_facts_module()
        old, new = self.rebased_fixture("subject")
        database = self.dir / "projection.sqlite3"
        env = {"AGENT_LEDGER_FILE": str(self.ledger), "AGENT_EQUIVALENCE_CACHE": str(self.dir / "eq.json")}
        with patch.object(module, "INDEX", self.index), patch.dict(module.os.environ, env):
            module.rebuild(argparse.Namespace(database=str(database), root=str(self.repo)), emit=False)
        sessions, ledger = self.tr.read_jsonl(self.index), []
        direct = facts_module.DirectFacts(self.repo, sessions, ledger)
        facts = facts_module.ProjectionFacts.open(database, self.repo, self.index, self.ledger, direct)
        self.assertIsNotNone(facts)
        connection = sqlite3.connect(database)
        edges = connection.execute("SELECT dst_id, kind, via FROM trace_edges WHERE src_type='commit' AND src_id=? AND kind='equivalent'", (new,)).fetchall()
        self.assertEqual(edges, [(old[:7], "equivalent", "patch-id")])
        self.assertEqual(connection.execute("SELECT subject FROM git_commits WHERE sha=?", (new,)).fetchone()[0], "feat: add a (reworded)")
        self.assertEqual([c["sha"] for c in facts_module.search_commits(connection, "reworded", 5)], [new])
        connection.close()
        via_projection = self.tr.trace(self.repo, new, sessions, ledger, facts=facts)
        via_direct = self.tr.trace(self.repo, new, sessions, ledger, facts=direct)
        self.assertEqual(via_projection["engine"], "projection")
        self.assertEqual(via_direct["engine"], "direct")
        for key in ("commits", "sessions", "prs", "issues", "why"):
            self.assertEqual(via_projection[key], via_direct[key], key)
        self.write_jsonl(self.index, [*sessions, {"session_id": "codex:later", "started_at": "2026-11-22T00:00:00+00:00"}])
        self.assertIsNone(facts_module.ProjectionFacts.open(database, self.repo, self.index, self.ledger, direct))
        facts.connection.close()

    # doctor
    def test_doctor_reports_registration_command_and_equivalence_coverage(self) -> None:
        module = load_agentctl_module()
        old, new = self.rebased_fixture("subject")
        self.commit("feat: tagged\n\nAgent-Session: claude-code:abc-1", name="t.txt")
        self.commit("chore: nobody knows", name="n.txt")
        env = {"AGENT_LEDGER_FILE": str(self.ledger), "AGENT_EQUIVALENCE_CACHE": str(self.dir / "eq.json"), "CLAUDE_CODE_SESSION_ID": "fresh-1"}
        with patch.object(module, "INDEX", self.index), patch.dict(module.os.environ, env):
            report = module.traceability_report(self.repo)
        self.assertIs(report["current_session_registered"], False)
        self.assertIn("agentctl sessions register", report["register_command"])
        coverage = report["main_coverage"]
        self.assertEqual((coverage["trailer"], coverage["rebase-equivalent"], coverage["unresolved"]), (1, 1, 3))  # base + main-moved + nobody
        self.assertEqual(coverage["coverage_pct"], 40.0)

    # -- round 3: heal vs maintain, ended_at, --infer
    def test_heal_never_rewrites_tracked_logs_but_maintain_compacts(self) -> None:
        module = load_agentctl_module()
        rows = [{"session_id": "a:1", "status": "active"}, {"session_id": "a:1", "status": "completed"}]
        self.write_jsonl(self.index, rows)
        before = self.index.read_text()
        args = argparse.Namespace(database=str(self.dir / "k.sqlite3"))
        with patch.object(module, "INDEX", self.index), patch.object(module, "rebuild", return_value=0), \
             contextlib.redirect_stdout(io.StringIO()):
            module.heal(args)
            self.assertEqual(self.index.read_text(), before)
            module.maintain(args)
        self.assertEqual(len(self.index.read_text().splitlines()), 1)
        self.assertEqual(json.loads(self.index.read_text())["status"], "completed")

    def test_session_end_records_ended_at(self) -> None:
        env = {"CLAUDE_CODE_SESSION_ID": "abc-1"}
        self.cli("sessions", "--root", str(self.repo), "register", "--summary", "work", env=env)
        self.assertNotIn("ended_at", self.tr.fold_records(self.tr.read_jsonl(self.index))[0])
        self.cli("sessions", "--root", str(self.repo), "register", "--status", "completed", env=env)
        record = self.tr.fold_records(self.tr.read_jsonl(self.index))[0]
        self.assertEqual(record["status"], "completed")
        self.assertIsNotNone(self.tr.parse_time(record["ended_at"]))

    def test_trace_infer_is_opt_in_labelled_and_not_coverage(self) -> None:
        module = load_agentctl_module()
        self.commit("chore: base")
        window = lambda day: clean_env(GIT_AUTHOR_DATE=f"2026-11-{day}T10:00:00+00:00", GIT_COMMITTER_DATE=f"2026-11-{day}T10:00:00+00:00")  # noqa: E731
        with_ref = self.commit("feat: in window\n\nCloses #8", name="a", env=window("20"))
        no_ref = self.commit("chore: in window", name="b", env=window("20"))
        outside = self.commit("chore: outside", name="c", env=window("25"))
        self.write_jsonl(self.index, [
            {"session_id": "claude-code:s1", "harness": "claude-code", "started_at": "2026-11-20T09:00:00+00:00", "ended_at": "2026-11-20T12:00:00+00:00",
             "summary": "S1", "issues": ["#8"]},
            {"session_id": "claude-code:s2", "harness": "claude-code", "started_at": "2026-11-20T09:30:00+00:00", "summary": "S2", "issues": ["#99"]},
            {"session_id": "claude-code:s3", "harness": "claude-code", "started_at": "2026-11-21T09:30:00+00:00", "summary": "S3"}])
        self.write_jsonl(self.ledger, [])

        def sessions(sha: str, *flags: str) -> dict[str, dict]:
            result = json.loads(self.cli("trace", sha, "--json", "--root", str(self.repo), *flags).stdout)
            return {s["session_id"]: s for s in result["sessions"]}

        self.assertEqual(sessions(with_ref), {})  # opt-in only
        found = sessions(with_ref, "--infer")
        self.assertEqual(list(found), ["claude-code:s1"])  # s2 shares no PR/issue; s3 is outside the window
        self.assertTrue(found["claude-code:s1"]["inferred"])
        evidence = found["claude-code:s1"]["via"][0]
        self.assertTrue(evidence.startswith("inferred:") and "ended_at" in evidence and "#8" in evidence)
        both = sessions(no_ref, "--infer")  # no refs on the commit: time window only; s2 ends at the next session start
        self.assertEqual(set(both), {"claude-code:s1", "claude-code:s2"})
        self.assertIn("time only", both["claude-code:s2"]["via"][0])
        self.assertIn("next session start", both["claude-code:s2"]["via"][0])
        self.assertEqual(sessions(outside, "--infer"), {})
        self.assertIn("INFERRED", self.cli("trace", with_ref, "--infer", "--root", str(self.repo)).stdout)
        env = {"AGENT_LEDGER_FILE": str(self.ledger), "AGENT_EQUIVALENCE_CACHE": str(self.dir / "eq.json")}
        with patch.object(module, "INDEX", self.index), patch.dict(module.os.environ, env):
            coverage = module.history_coverage(self.repo, self.tr.read_jsonl(self.index), [], 10)
            database = self.dir / "infer.sqlite3"
            module.rebuild(argparse.Namespace(database=str(database), root=str(self.repo)), emit=False)
        self.assertEqual(coverage["unresolved"], 4)  # inference never counts toward coverage
        connection = sqlite3.connect(database)
        self.assertEqual(connection.execute("SELECT COUNT(*) FROM trace_edges WHERE dst_id LIKE 'claude-code:s%' AND src_type='commit'").fetchone()[0], 0)
        connection.close()

    # -- G. provenance
    def test_provenance_links_run_to_commit_pr_and_sessions(self) -> None:
        refs = self.squash_fixture()
        env = {"GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "2", "GITHUB_REPOSITORY": "o/r", "GITHUB_WORKFLOW": "Web Build", "GITHUB_EVENT_NAME": "push"}
        summary, out = self.dir / "summary.md", self.dir / "out/p.json"
        self.cli("provenance", "--root", str(self.repo), "--sha", refs["squash"], "--triggering-run", "55", "--out", str(out), "--summary", str(summary), env=env)
        value = json.loads(out.read_text())
        self.assertEqual((value["run_id"], value["commit"], value["prs"], value["triggering_run_id"]), ("123", refs["squash"], ["#7"], "55"))
        self.assertEqual({s["session_id"] for s in value["sessions"]}, {"claude-code:abc-1", "codex:zzz"})
        self.assertTrue(value["run_url"].endswith("/o/r/actions/runs/123"))
        self.assertIn("claude-code:abc-1", summary.read_text())

    # -- H. doctor
    def test_doctor_reports_traceability_gaps(self) -> None:
        module = load_agentctl_module()
        self.commit("chore: untracked")
        with patch.object(module, "INDEX", self.index), patch.dict(module.os.environ, {"AGENT_LEDGER_FILE": str(self.ledger)}):
            self.write_jsonl(self.index, [{"session_id": "claude-code:e", "started_at": "2026-11-22T00:00:00+00:00"}])
            self.write_jsonl(self.ledger, [{"timestamp": "2026-11-23T00:00:00+00:00", "event": "no session"}])
            report = module.traceability_report(self.repo)
        self.assertEqual(report["sessions_without_refs"], ["claude-code:e"])
        self.assertEqual(report["ledger_entries_without_session"], 1)
        self.assertEqual(len(report["recent_commits_without_session"]), 1)
        self.assertFalse(report["hooks"]["installed"])


FAKE_GCLOUD = r'''#!/usr/bin/env python3
import os, pathlib, shutil, sys
root = pathlib.Path(os.environ["FAKE_GCS_ROOT"])
args = sys.argv[1:]
root.mkdir(parents=True, exist_ok=True)
with open(root / "calls.log", "a") as log:
    log.write(" ".join(args) + "\n")
def local(uri):
    return root / "objects" / uri[len("gs://"):]
if args[:1] == ["auth"]:
    print("tester@example.com" if os.environ.get("FAKE_GCLOUD_AUTH", "1") == "1" else "")
    sys.exit(0)
if args[:1] == ["version"]:
    sys.exit(0)
if args[:3] == ["storage", "buckets", "create"]:
    sys.exit(0)
if args[:2] == ["storage", "cp"]:
    if os.environ.get("FAKE_GCLOUD_FAIL"):
        print("ERROR: Reauthentication required. Please run: gcloud auth login", file=sys.stderr)
        sys.exit(1)
    clobber, positional, items = True, [], iter(args[2:])
    for item in items:
        if item == "--no-clobber":
            clobber = False
        elif item == "--project":
            next(items)
        else:
            positional.append(item)
    source, destination = positional
    if destination.startswith("gs://"):
        target = local(destination)
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and not clobber:
            sys.exit(0)
        shutil.copyfile(source, target)
    else:
        origin = local(source)
        if not origin.exists():
            print("ERROR: 404 object not found", file=sys.stderr)
            sys.exit(1)
        shutil.copyfile(origin, destination)
    sys.exit(0)
if args[:2] == ["storage", "ls"]:
    directory = local(args[2])
    found = sorted(p for p in directory.iterdir() if p.is_file()) if directory.is_dir() else []
    if not found:
        print("ERROR: One or more URLs matched no objects.", file=sys.stderr)
        sys.exit(1)
    for path in found:
        print("gs://" + str(path.relative_to(root / "objects")))
    sys.exit(0)
print("fake gcloud: unsupported " + " ".join(args), file=sys.stderr)
sys.exit(2)
'''


def fake_token(prefix: str, length: int = 36) -> str:
    """Synthetic credential built at runtime so no secret-shaped literal sits in the repo."""
    return prefix + ("A1b2" * ((length + 3) // 4))[:length]


class ArchiveTest(unittest.TestCase):
    """Session transcript archive (#278): redaction, bundle, transport, commands."""

    def setUp(self) -> None:
        self.sa = load_session_archive_module()
        self.tr = load_traceability_module()
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.dir = Path(self._tmp.name)
        self.home = self.dir / "home"
        self.gcs = self.dir / "gcs"
        self.bin = self.dir / "bin"
        self.bin.mkdir()
        gcloud = self.bin / "gcloud"
        gcloud.write_text(FAKE_GCLOUD)
        gcloud.chmod(0o755)
        self.config = {"project": "proj", "bucket": "test-bucket", "location": "europe-north1", "prefix": "sessions/"}
        self.config_file = self.dir / "archive.json"
        self.config_file.write_text(json.dumps(self.config))
        self.index = self.dir / "index.jsonl"
        self.ledger = self.dir / "ledger.jsonl"
        self.native = "11111111-2222-3333-4444-555555555555"
        self.session = f"claude-code:{self.native}"
        self.token = fake_token("ghp_")
        project = self.home / ".claude/projects/-tmp-slug"
        (project / self.native / "subagents").mkdir(parents=True)
        (project / f"{self.native}.jsonl").write_text(
            json.dumps({"type": "user", "message": {"content": f"use {self.token} please, mail me at dev@example.org"}}) + "\n"
            + json.dumps({"type": "assistant", "message": {"content": "ok"}}) + "\n")
        (project / self.native / "subagents/agent-a1.jsonl").write_text(json.dumps({"type": "user", "message": "sub"}) + "\n")
        (project / self.native / "subagents/agent-a1.meta.json").write_text(json.dumps({"agentType": "Explore"}))
        self.gcloud = self.sa.Gcloud("proj", executable=str(gcloud))
        patcher = patch.dict(os.environ, {"FAKE_GCS_ROOT": str(self.gcs)})
        patcher.start()
        self.addCleanup(patcher.stop)

    def calls(self) -> list[str]:
        log = self.gcs / "calls.log"
        return log.read_text().splitlines() if log.exists() else []

    def env(self, **extra: str) -> dict[str, str]:
        env = clean_env(HOME=str(self.home), PATH=f"{self.bin}:{os.environ['PATH']}", FAKE_GCS_ROOT=str(self.gcs),
                        AGENT_SESSION_INDEX=str(self.index), AGENT_LEDGER_FILE=str(self.ledger),
                        AGENT_ARCHIVE_CONFIG=str(self.config_file), AGENT_SESSION_CACHE=str(self.dir / "cache"),
                        AGENT_KNOWLEDGE_DB=str(self.dir / "k.sqlite3"), CLAUDE_CODE_SESSION_ID=self.native)
        env.pop("CLAUDE_CONFIG_DIR", None)
        env.update(extra)
        return env

    def cli(self, *args: str, check: bool = True, **extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([str(CLI), *args], cwd=ROOT, env=self.env(**extra), check=check, capture_output=True, text=True)

    # -- redaction
    def test_each_redaction_rule_replaces_its_secret_shape(self) -> None:
        pem = "-----BEGIN " + "PRIVATE KEY-----\\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASC\\n-----END PRIVATE KEY-----"
        cases = {
            "github-token": [fake_token("ghp_"), fake_token("github_pat_", 30)],
            "anthropic-key": [fake_token("sk-ant-", 30)],
            "openai-key": [fake_token("sk-proj-", 30), fake_token("sk-", 30)],
            "slack-token": [fake_token("xoxb-", 30)],
            "aws-access-key": ["AKIA" + "A1" * 8],
            "google-oauth-token": [fake_token("ya29.", 30)],
            "google-api-key": [fake_token("AIza", 35)],
            "jwt": [".".join((fake_token("eyJ", 12), fake_token("eyJ", 12), fake_token("", 12)))],
            "pem-private-key": [pem, pem.replace("\\n", "\n")],
            "bearer-token": [fake_token("Authorization: Bearer ", 24)],
            "secret-assignment": [fake_token("MY_API_KEY=", 12), fake_token("DB_PASSWORD=", 12), "CLAUDE_CODE_MESSAGING_TOKEN=" + "9f" * 16],
            "email": ["dev@example.org"],
        }
        for rule, samples in cases.items():
            for sample in samples:
                with self.subTest(rule=rule, sample=sample[:12]):
                    redactor = self.sa.Redactor()
                    out = redactor.text(f"before {sample} after")
                    self.assertIn(f"[REDACTED:{rule}]" if rule not in {"secret-assignment", "bearer-token"} else "[REDACTED:", out)
                    self.assertTrue(redactor.counts[rule] >= 1, redactor.counts)
                    self.assertTrue(out.startswith("before ") and out.endswith(" after"))
                    self.assertEqual(redactor.scan(out), [])
                    secret_part = sample.split("=", 1)[-1].strip("'") if rule == "secret-assignment" else sample.split("Bearer ")[-1] if rule == "bearer-token" else sample
                    self.assertNotIn(secret_part, out)

    def test_email_exceptions_and_registry_values_from_env_files(self) -> None:
        redactor = self.sa.Redactor()
        kept = "noreply@anthropic.com 49699333+dependabot[bot]@users.noreply.github.com git@github.com icon@2x.png"
        self.assertEqual(redactor.text(kept), kept)
        env_file = self.dir / ".env"
        codecov_value = fake_token("", 16)
        env_file.write_text(f"CODECOV_TOKEN='{codecov_value}'\nFIREBASE_CLI_TOKEN=short\nFACEBOOK_CLIENT_TOKEN=publicvalue123\nUNLISTED=zzzzzzzzzzzz\n")
        secrets = self.sa.registry_secrets(ROOT / "scripts/secrets/registry.toml", {"CODEX_AUTH_JSON_B64": "env-supplied-value"}, [env_file])
        self.assertEqual(secrets, {"CODECOV_TOKEN": codecov_value, "CODEX_AUTH_JSON_B64": "env-supplied-value"})  # public, short, unlisted ignored
        redactor = self.sa.Redactor(secrets)
        out = redactor.text(f"a {codecov_value} b env-supplied-value c publicvalue123 d short")
        self.assertEqual(out, "a [REDACTED:CODECOV_TOKEN] b [REDACTED:CODEX_AUTH_JSON_B64] c publicvalue123 d short")
        self.assertEqual(redactor.scan(out), [])

    def test_env_dump_and_pem_inside_json_strings_stay_valid_jsonl(self) -> None:
        dump = "PATH=/usr/bin\nCLAUDE_CODE_MESSAGING_TOKEN=" + "ab12" * 8 + "\nHOME=/home/x"
        pem = "-----BEGIN " + "RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA\n-----END RSA PRIVATE KEY-----"
        line = json.dumps({"tool_result": {"stdout": dump, "key": pem, "nested": [f"mail dev@example.org"]}})
        out = self.sa.redact_jsonl(self.sa.Redactor(), "t.jsonl", (line + "\n" + line + "\n").encode()).decode()
        rows = [json.loads(row) for row in out.splitlines()]  # still valid JSONL
        self.assertEqual(len(rows), 2)
        stdout = rows[0]["tool_result"]["stdout"]
        self.assertIn("CLAUDE_CODE_MESSAGING_TOKEN=[REDACTED:secret-assignment]", stdout)
        self.assertIn("PATH=/usr/bin", stdout)
        self.assertNotIn("ab12ab12", out)
        self.assertEqual(rows[0]["tool_result"]["key"], "[REDACTED:pem-private-key]")
        self.assertEqual(rows[0]["tool_result"]["nested"], ["mail [REDACTED:email]"])

    def test_redaction_fails_closed_without_leaking_values(self) -> None:
        leaky = [("leaky", re.compile(r"SECRET\d+"), "SECRET1")]  # replacement still matches: the re-scan must abort
        with self.assertRaises(self.sa.ArchiveError) as caught:
            self.sa.redact_jsonl(self.sa.Redactor(patterns=leaky), "t.jsonl", b'{"a":"x"}\n{"a":"SECRET123456"}\n')
        message = str(caught.exception)
        self.assertIn("t.jsonl:2", message)
        self.assertIn("leaky", message)
        self.assertNotIn("SECRET1", message)
        with self.assertRaises(self.sa.ArchiveError) as invalid:
            self.sa.redact_jsonl(self.sa.Redactor(), "t.jsonl", b'{"a":1}\nnot json with ' + fake_token("ghp_").encode() + b"\n")
        self.assertIn("t.jsonl:2", str(invalid.exception))
        self.assertNotIn("ghp_", str(invalid.exception))

    # -- bundle
    def test_bundle_is_deterministic_and_normalized(self) -> None:
        files = self.sa.find_transcripts(self.session, self.home)
        self.assertEqual([name for name, _ in files], ["transcript.jsonl", "subagents/agent-a1.jsonl", "subagents/agent-a1.meta.json"])
        first = self.sa.build_bundle(self.session, files, self.sa.Redactor(), self.config)
        second = self.sa.build_bundle(self.session, list(reversed(files)), self.sa.Redactor(), self.config)
        self.assertEqual(first.sha256, second.sha256)
        self.assertEqual(first.uri, f"gs://test-bucket/sessions/claude-code/{self.native}/{first.sha256}.tar.gz")
        self.assertEqual(first.data[4:8], b"\x00\x00\x00\x00")  # gzip mtime = 0
        import io as _io
        import tarfile as _tar
        with _tar.open(fileobj=_io.BytesIO(first.data), mode="r:gz") as tar:
            members = tar.getmembers()
        self.assertEqual([m.name for m in members], sorted(m.name for m in members))
        self.assertTrue(all((m.mtime, m.uid, m.gid, m.uname, m.gname) == (0, 0, 0, "", "") for m in members))
        self.assertEqual(first.manifest["redactions"], {"email": 1, "github-token": 1})
        self.assertEqual({f["path"] for f in first.manifest["files"]}, {n for n, _ in files})

    # -- archive / fetch
    def test_archive_uploads_redacted_immutable_bundle_and_fetch_verifies(self) -> None:
        result = self.sa.archive(self.session, self.config, self.sa.Redactor(), self.gcloud, home=self.home)
        stored = self.gcs / "objects" / result["uri"][len("gs://"):]
        self.assertTrue(stored.is_file())
        self.assertTrue(any("--no-clobber" in call for call in self.calls() if "storage cp" in call))
        # immutable: an existing object is never overwritten
        stored.write_bytes(b"pre-existing")
        self.sa.archive(self.session, self.config, self.sa.Redactor(), self.gcloud, home=self.home)
        self.assertEqual(stored.read_bytes(), b"pre-existing")
        stored.write_bytes(self.sa.build_bundle(self.session, self.sa.find_transcripts(self.session, self.home), self.sa.Redactor(), self.config).data)
        path = self.sa.fetch(result["uri"], self.gcloud, self.dir / "out")
        text = (path / "transcript.jsonl").read_text()
        self.assertNotIn(self.token, text)
        self.assertIn("[REDACTED:github-token]", text)
        self.assertTrue((path / "subagents/agent-a1.meta.json").is_file())
        self.assertEqual(json.loads((path / "manifest.json").read_text())["session_id"], self.session)

    def test_fetch_rejects_sha_mismatch_and_unsafe_archives(self) -> None:
        result = self.sa.archive(self.session, self.config, self.sa.Redactor(), self.gcloud, home=self.home)
        stored = self.gcs / "objects" / result["uri"][len("gs://"):]
        stored.write_bytes(stored.read_bytes() + b"tampered")
        with self.assertRaisesRegex(self.sa.ArchiveError, "sha256 mismatch"):
            self.sa.fetch(result["uri"], self.gcloud, self.dir / "bad")
        self.assertFalse((self.dir / "bad/manifest.json").exists())
        import hashlib as _hash
        import io as _io
        import tarfile as _tar

        def crafted(name: str, kind: bytes = _tar.REGTYPE, link: str = "") -> bytes:
            buffer = _io.BytesIO()
            with _tar.open(fileobj=buffer, mode="w:gz") as tar:
                info = _tar.TarInfo(name)
                info.type, info.linkname = kind, link
                tar.addfile(info, _io.BytesIO(b"x") if kind == _tar.REGTYPE else None)
            return buffer.getvalue()

        for label, data in {"dotdot": crafted("../evil"), "absolute": crafted("/etc/evil"), "symlink": crafted("link", _tar.SYMTYPE, "/etc/passwd"),
                            "hardlink": crafted("hard", _tar.LNKTYPE, "x")}.items():
            with self.subTest(label):
                bundle = self.dir / f"{label}.tar.gz"
                bundle.write_bytes(data)
                with self.assertRaisesRegex(self.sa.ArchiveError, "unsafe"):
                    self.sa.extract_bundle(bundle, self.dir / f"extract-{label}")
                self.assertFalse((self.dir / "evil").exists())
        sha = _hash.sha256(crafted("../evil")).hexdigest()
        uri = f"gs://test-bucket/sessions/claude-code/{self.native}/{sha}.tar.gz"
        target = self.gcs / "objects" / uri[len("gs://"):]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(crafted("../evil"))
        with self.assertRaisesRegex(self.sa.ArchiveError, "unsafe"):
            self.sa.fetch(uri, self.gcloud, self.dir / "e2e")

    def test_dry_run_makes_no_gcloud_calls(self) -> None:
        result = self.sa.archive(self.session, self.config, self.sa.Redactor(), self.gcloud, dry_run=True, home=self.home)
        self.assertEqual(result["status"], "dry-run")
        self.assertEqual(self.calls(), [])
        out = json.loads(self.cli("sessions", "archive", "--dry-run", "--json").stdout)
        self.assertEqual((out["status"], out["redactions"]), ("dry-run", {"email": 1, "github-token": 1}))
        self.assertTrue(out["uri"].startswith("gs://test-bucket/sessions/claude-code/"))
        self.assertEqual(self.calls(), [])
        self.assertFalse(self.index.exists(), "dry run records nothing")

    def test_session_archive_fetch_commands_and_index_record(self) -> None:
        archived = json.loads(self.cli("sessions", "archive", "--json").stdout)
        record = self.tr.fold_records(self.tr.read_jsonl(self.index))[0]
        self.assertEqual((record["transcript"], record["transcript_sha256"]), (archived["uri"], archived["sha256"]))
        self.assertIsNotNone(self.tr.parse_time(record["archived_at"]))
        fetched = self.cli("sessions", "fetch", self.session).stdout.strip()
        self.assertTrue(fetched.startswith(str(self.dir / "cache/claude-code")) and fetched.endswith(archived["sha256"]))
        self.assertTrue((Path(fetched) / "transcript.jsonl").is_file())
        before = len(self.calls())
        self.assertEqual(self.cli("sessions", "fetch", self.session).stdout.strip(), fetched)  # cached
        self.assertEqual(len(self.calls()), before)
        traced = json.loads(self.cli("trace", self.session, "--json", "--root", str(ROOT)).stdout)
        self.assertEqual(traced["sessions"][0]["archive"]["fetch"], f"scripts/agents/agentctl sessions fetch {self.session}")
        self.assertIn("fetch:   scripts/agents/agentctl sessions fetch", self.cli("trace", self.session, "--root", str(ROOT)).stdout)

    def test_session_completion_archives_automatically_and_never_blocks(self) -> None:
        ended = json.loads(self.cli("sessions", "--root", str(ROOT), "register", "--status", "completed", "--summary", "work").stdout)
        self.assertEqual(ended["archive"]["status"], "archived")
        record = self.tr.fold_records(self.tr.read_jsonl(self.index))[0]
        self.assertEqual((record["status"], record["transcript"]), ("completed", ended["archive"]["uri"]))
        calls = len(self.calls())
        skipped = json.loads(self.cli("sessions", "--root", str(ROOT), "register", "--status", "completed", "--no-archive").stdout)
        self.assertNotIn("archive", skipped)
        self.assertEqual(len(self.calls()), calls)
        self.index.unlink()
        failed = self.cli("sessions", "--root", str(ROOT), "register", "--status", "completed", "--summary", "again", FAKE_GCLOUD_FAIL="1")
        self.assertEqual(failed.returncode, 0)
        self.assertIn("warning: session transcript not archived", failed.stderr)
        self.assertIn("gcloud auth login", failed.stderr)
        self.assertEqual(json.loads(failed.stdout)["archive"]["status"], "failed")
        self.assertNotIn("transcript", self.tr.fold_records(self.tr.read_jsonl(self.index))[0])
        nothing = json.loads(self.cli("sessions", "--root", str(ROOT), "register", "--status", "completed", CLAUDE_CODE_SESSION_ID="no-transcript").stdout)
        self.assertEqual(nothing["archive"]["status"], "skipped")

    def test_unauthenticated_gcloud_gives_actionable_message(self) -> None:
        result = self.cli("sessions", "archive", check=False, FAKE_GCLOUD_AUTH="0")
        self.assertEqual(result.returncode, 2)
        self.assertIn("gcloud auth login", result.stderr)
        with patch.object(self.sa.shutil, "which", return_value=None), self.assertRaisesRegex(self.sa.ArchiveError, "gcloud not found"):
            self.sa.archive(self.session, self.config, self.sa.Redactor(), self.sa.Gcloud(), home=self.home)

    def test_provision_prints_owner_commands_and_apply_runs_them(self) -> None:
        printed = self.cli("sessions", "provision-archive").stdout
        for part in ("gs://test-bucket", "--project=proj", "--location=europe-north1", "--uniform-bucket-level-access", "--public-access-prevention", "Owner-only"):
            self.assertIn(part, printed)
        self.assertEqual(self.calls(), [])
        self.cli("sessions", "provision-archive", "--apply")
        self.assertTrue(any(call.startswith("storage buckets create gs://test-bucket") for call in self.calls()))

    def test_doctor_archive_report_and_index_transcript_rule(self) -> None:
        module = load_agentctl_module()
        self.index.write_text(json.dumps({"session_id": self.session, "started_at": "2026-11-22T00:00:00+00:00"}) + "\n")
        with patch.dict(module.os.environ, self.env()):
            report = module.archive_report(self.tr.read_jsonl(self.index))
        self.assertEqual((report["configured"], report["gcloud_available"], report["gcloud_authenticated"]), (True, True, True))
        self.assertEqual((report["sessions_without_archive"], report["bucket"]), (1, "gs://test-bucket/sessions/"))
        spec = importlib.util.spec_from_file_location("check_logs_archive", ROOT / "scripts/agents/check_logs.py")
        logs = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(logs)
        root = self.dir / "repo"
        (root / ".agents/sessions").mkdir(parents=True)
        index = root / ".agents/sessions/index.jsonl"
        base = {"session_id": self.session, "started_at": "2026-11-22T00:00:00+00:00"}
        index.write_text(json.dumps({**base, "transcript": "/home/me/.claude/x.jsonl"}) + "\n")
        self.assertTrue(any("gs://" in e for e in logs.check(root, [".agents/sessions/index.jsonl"])))
        index.write_text(json.dumps({**base, "transcript": "gs://b/sessions/claude-code/x/" + "a" * 64 + ".tar.gz"}) + "\n")
        self.assertEqual(logs.check(root, [".agents/sessions/index.jsonl"]), [])
        legacy = {"session_id": "01a1", "started_at": "2026-11-20T00:00:00+00:00", "transcript": "/old/local/path"}
        index.write_text(json.dumps(legacy) + "\n")
        self.assertEqual(logs.check(root, [".agents/sessions/index.jsonl"]), [])


if __name__ == "__main__":
    unittest.main()
