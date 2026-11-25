"""Nightly audit behavior through collection, comparison, and publishing."""

from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import agent_audit as audit


METRIC = "ci.validation.failure-rate"


def finding(metric=METRIC, title="Validation failures"):
    return {"metric_id": metric, "title": title, "evidence": f"{metric} rose",
            "recommendation": "Fix the failing step", "acceptance": "Validation passes"}


def snapshot(metrics, previous=None):
    deltas, statuses = audit.compare(metrics, previous)
    return {"status": "completed", "run_id": "123", "baseline": previous is None,
            "start": "2026-11-24T00:00:00+00:00", "end": "2026-11-25T00:00:00+00:00",
            "metrics": metrics, "deltas": deltas, "statuses": statuses,
            "prior_findings": previous["findings"] if previous else [],
            "previous_run_id": previous["run_id"] if previous else None}


class AuditTests(unittest.TestCase):
    def test_thresholds_are_alternatives_and_force_bypasses_them(self):
        self.assertFalse(audit.threshold_met(9, 4))
        self.assertTrue(audit.threshold_met(10, 0))
        self.assertTrue(audit.threshold_met(0, 5))
        self.assertTrue(audit.threshold_met(0, 0, force=True))
        self.assertFalse(audit.threshold_met(10, 5, minimum_sessions=11, minimum_merged=6))
        complete = {"status": "completed", "end": "2026-11-20"}
        self.assertEqual(audit.previous_audit([complete, {"status": "deferred"}]), complete)

    def test_metrics_from_fixture(self):
        start = datetime(2026, 11, 24, tzinfo=timezone.utc)
        end = datetime(2026, 11, 25, tzinfo=timezone.utc)
        first = "2026-11-24T01:00:00Z"
        last = "2026-11-24T03:00:00Z"
        data = {
            "merged": [{"number": 42, "created_at": first, "merged_at": last,
                        "merge_bot": False, "rebases": 1, "sent_behind": 3, "timeline": [
                            {"event": "labeled", "label": {"name": "risk/security"}, "created_at": first},
                            {"event": "head_ref_force_pushed", "created_at": last},
                            {"event": "reviewed", "submitted_at": last, "commit_id": "abc"},
                        ]}],
            "open": [], "held": 2,
            "reviews": [{"pr": 42, "head_sha": "abc", "provider": "codex",
                         "status": "approved", "summary": "Review", "diff_truncated": True}],
            "runs": [{"name": "Validation", "conclusion": "failure", "run_attempt": 2,
                      "run_started_at": first, "updated_at": last, "maven_429": True},
                     {"name": "Agent review", "conclusion": "cancelled", "run_attempt": 1,
                      "event": "workflow_dispatch"}],
            "sessions": [{"session_id": "codex:a", "provider": "openai", "harness": "codex",
                          "issues": ["#42"], "status": "completed"}],
            "ledger": [{"run_id": "r", "status": "unavailable"}],
            "commit_trailers": ["codex:a", ""],
        }
        metrics = audit.compute_metrics(data, start, end)
        expected = {
            "pr.merged": 1, "pr.open": 0, "pr.merge-hours-p50": 2, "pr.merge-hours-p90": 2,
            "pr.42.owner-wait-hours": 2, "pr.42.rebases": 1, "pr.42.force-pushes": 1,
            "pr.42.review-rounds": 1, "pr.human-merge-share": 1,
            "process.merge-42.sent-behind": 3, "process.merge-auto-removed": 2,
            "review.codex.approved-share": 1, "review.codex.hollow-share": 1,
            "review.redispatched": 1, "ci.maven-429": 1, METRIC: 1,
            "ci.agent-review.cancel-rate": 1, "ci.validation.rerun-rate": 1,
            "ci.validation.median-hours": 2, "agent.provider.openai": 1, "agent.harness.codex": 1,
            "agent.quota-or-unavailable-runs": 1, "agent.closed-lanes-without-delivery": 1,
            "agent.commits-missing-trailer": 1,
        }
        self.assertEqual({key: metrics[key] for key in expected}, expected)

    def test_baseline_then_all_recommendation_statuses(self):
        metrics = {METRIC: .7, "ci.maven-429": 3, "pr.42.rebases": 1, "pr.42.force-pushes": 1}
        first = snapshot(metrics)
        audit.apply_model(first, {"status": "succeeded"}, {"findings": [finding(m) for m in metrics]})
        self.assertIn("Baseline", audit.report(first))
        self.assertEqual(first["deltas"], {})
        second = snapshot({METRIC: .4, "ci.maven-429": 0, "pr.42.rebases": 1, "pr.42.force-pushes": 2}, first)
        self.assertEqual(second["deltas"], {METRIC: -.3, "ci.maven-429": -3,
                                            "pr.42.rebases": 0, "pr.42.force-pushes": 1})
        self.assertEqual(list(second["statuses"].values()), ["improving", "resolved", "unchanged", "regressed"])

    def test_fingerprint_ignores_prose_and_filters_uncited_findings(self):
        metrics = {METRIC: .9}
        first = audit.findings_from_model({"findings": [finding(), finding(title="Renamed")]}, metrics)
        second = audit.findings_from_model({"findings": [
            finding("missing.metric"), finding() | {"evidence": "No citation"}, finding(title="Renamed")]}, metrics)
        self.assertEqual(len(first), 1)
        self.assertEqual(len(second), 1)
        self.assertEqual(first[0]["id"], second[0]["id"])

    def test_report_escapes_model_markup(self):
        result = snapshot({METRIC: .9})
        audit.apply_model(result, {"status": "succeeded"},
                          {"findings": [finding(title="<script>|[@owner](url)")]})
        markdown = audit.report(result)
        self.assertIn("&lt;script&gt;\\|\\[&#64;owner\\]\\(url\\)", markdown)
        self.assertNotIn("<script>", markdown)

    def test_unavailable_model_publishes_metrics_only(self):
        first = snapshot({METRIC: .9})
        audit.apply_model(first, {"status": "succeeded"}, {"findings": [finding()]})
        result = snapshot({METRIC: .8}, first)
        reset = "2026-11-26T00:00:00Z"
        audit.apply_model(result, {"status": "unavailable", "resets_at": reset}, {"findings": [finding()]})
        self.assertEqual(audit.repeated_findings(result), [])
        markdown = audit.report(result)
        self.assertIn(f"| `{METRIC}` | 0.8 | -0.1 |", markdown)
        self.assertIn(reset, markdown)
        self.assertNotIn("Fix the failing step", markdown)

    def test_stale_artifact_cannot_rewind_history(self):
        old = snapshot({METRIC: .9})
        newer = old | {"run_id": "124", "end": "2026-11-26T00:00:00+00:00"}
        self.assertFalse(audit.current_snapshot(old, [newer]))

    @patch.dict("os.environ", {"GITHUB_REPOSITORY": "example/repo"})
    def test_repeated_finding_creates_then_updates_one_issue(self):
        first = snapshot({METRIC: .9})
        payload = {"findings": [finding()]}
        audit.apply_model(first, {"status": "succeeded"}, payload)
        self.assertEqual(audit.repeated_findings(first), [])
        result = snapshot({METRIC: .9}, first)
        audit.apply_model(result, {"status": "succeeded"}, payload)
        tracking = {"number": 2, "node_id": "track", "user": {"login": audit.BOT},
                    "body": "<!-- agent-audit:tracking -->\nNightly results"}
        issues = [tracking]
        writes = []

        def github(endpoint, *, method, data):
            writes.append((endpoint, method, data))
            if endpoint == "graphql":
                return {"data": {"repository": {"pinnedIssues": {"nodes": [{"issue": {"id": "track"}}]}}}}
            if endpoint == "repos/example/repo/issues" and method == "POST":
                issues.append({"number": 3, "user": {"login": audit.BOT}, **data})
            return None

        with patch.object(audit, "pages", side_effect=lambda repo, suffix, **kwargs: issues if suffix == "issues" else []):
            with patch.object(audit, "gh_api", side_effect=github), patch.object(audit, "fetch_history"), \
                    patch.object(audit, "rows", return_value=[first | {"run_id": "122", "end": first["start"]}]):
                result["previous_run_id"] = "122"
                audit.publish(result)
                audit.publish(result)
        self.assertEqual(len(issues), 2)
        self.assertEqual(sum(endpoint.endswith("/issues/3") and method == "PATCH"
                             for endpoint, method, data in writes), 1)


    @patch.dict("os.environ", {"GITHUB_REPOSITORY": "example/repo"})
    def test_deferred_snapshot_publishes_a_deferred_comment_only(self):
        deferred = {"run_id": "200", "start": "2026-11-24T00:00:00+00:00",
                    "end": "2026-11-25T00:00:00+00:00", "sessions": 3, "merged": 1,
                    "status": "deferred", "previous_run_id": None}
        tracking = {"number": 2, "node_id": "track", "user": {"login": audit.BOT},
                    "body": "<!-- agent-audit:tracking -->\nNightly results"}
        writes = []

        def github(endpoint, *, method, data):
            writes.append((endpoint, method, data))
            if endpoint == "graphql":
                return {"data": {"repository": {"pinnedIssues": {"nodes": [{"issue": {"id": "track"}}]}}}}
            return None

        with patch.object(audit, "pages", side_effect=lambda repo, suffix, **kwargs: [tracking] if suffix == "issues" else []), \
                patch.object(audit, "gh_api", side_effect=github), patch.object(audit, "fetch_history"), \
                patch.object(audit, "rows", return_value=[]):
            audit.publish(deferred)
        posts = [(endpoint, data) for endpoint, method, data in writes if method == "POST" and endpoint != "graphql"]
        self.assertEqual([endpoint for endpoint, _ in posts], ["repos/example/repo/issues/2/comments"])
        self.assertIn("Audit deferred", posts[0][1]["body"])

    def test_unresolvable_head_makes_sent_behind_unknown(self):
        merge = {"number": 1, "merge_commit_sha": "tip", "commits": 1, "base": {"ref": "develop"},
                 "merged_at": "2026-11-24T02:00:00Z"}
        candidate = {"number": 2, "base": {"ref": "develop"}, "created_at": "2026-11-24T01:00:00Z",
                     "head": {"sha": "missing"}, "timeline": []}
        with patch.object(audit, "git", return_value="base\n"), \
                patch.object(audit, "is_ancestor", return_value=None):
            self.assertIsNone(audit.count_behind(merge, [merge, candidate]))
        with patch.object(audit, "git", return_value="base\n"), \
                patch.object(audit, "is_ancestor", side_effect=lambda ancestor, head: ancestor == "base"):
            self.assertEqual(audit.count_behind(merge, [merge, candidate]), 1)

    def test_malformed_router_output_keeps_the_deterministic_report(self):
        metrics = {METRIC: .9}
        workflow = json.loads(audit.WORKFLOW.read_text())
        with tempfile.TemporaryDirectory() as directory:
            workflow_path = Path(directory) / "workflow.json"
            workflow_path.write_text(json.dumps(workflow))
            snapshot_path = Path(directory) / "audit.json"
            snapshot_path.write_text(json.dumps(snapshot(metrics) | {"findings": [], "model": {}}))
            crashed = subprocess.CompletedProcess([], 1, stdout="provider crashed\n", stderr="")
            with patch.object(audit, "WORKFLOW", workflow_path), \
                    patch.object(audit.shutil, "which", side_effect=lambda name: "/bin/true" if name == "codex" else None), \
                    patch.object(audit.subprocess, "run", return_value=crashed):
                audit.model(snapshot_path)
            saved = json.loads(snapshot_path.read_text())
            self.assertEqual(json.loads(workflow_path.read_text()), workflow)
        self.assertEqual(saved["model"]["status"], "unavailable")
        self.assertEqual(saved["metrics"], metrics)
        self.assertEqual(saved["findings"], [])
        self.assertEqual(audit.routed_result('{"status": "succeeded", "steps": []}')[0]["status"], "invalid-output")


if __name__ == "__main__":
    unittest.main()
