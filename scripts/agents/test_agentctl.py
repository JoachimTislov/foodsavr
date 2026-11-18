#!/usr/bin/env python3
"""Focused tests for the dependency-free agent control plane."""

from __future__ import annotations

import json
import argparse
import contextlib
import importlib.util
import os
import io
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
CLI = ROOT / "scripts/agents/agentctl"
WORKFLOW = ROOT / ".agents/workflows/repository-health.json"


def load_agentctl_module():
    spec = importlib.util.spec_from_file_location("agentctl_under_test", ROOT / "scripts/agents/agentctl.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


class AgentctlTest(unittest.TestCase):
    def run_cli(self, *arguments: str, database: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(CLI), "--database", str(database), *arguments],
            cwd=ROOT,
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

    def test_ledger_and_session_references_are_preserved(self) -> None:
        module = load_agentctl_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".agents").mkdir()
            (root / ".agents/ledger.md").write_text("|---|---|\n")
            index = root / "sessions.jsonl"
            with patch.object(module, "ROOT", root), patch.object(module, "INDEX", index):
                module.append_session_record("fake", "session-1", "run-1", "summary", references={"issues": ["#212"], "prs": ["#236"]})
                module.append_ledger_event("run-1", "audit", "fake", "succeeded", references={"issues": ["#212"], "prs": ["#236|injected\nrow"]})
            session = json.loads(index.read_text())
            self.assertEqual(session["issues"], ["#212"])
            self.assertEqual(session["prs"], ["#236"])
            ledger = (root / ".agents/ledger.md").read_text()
            self.assertIn("references: issues: #212; prs: #236 injected row", ledger)
            self.assertEqual(len(ledger.splitlines()), 2)

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
            self.assertEqual(result["usage"]["total_tokens"], 10)
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

    def test_router_plan_has_a_local_policy_safe_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_cli("router", "plan", str(WORKFLOW), database=Path(directory) / "db", check=False)
            plan = json.loads(result.stdout)
            self.assertEqual(plan["fallback"]["strategy"], "first-available-policy-safe")
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


if __name__ == "__main__":
    unittest.main()
