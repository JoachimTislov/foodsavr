#!/usr/bin/env python3
"""Unit tests for scripts/github/pr_review.py."""

from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("pr_review", ROOT / "scripts/github/pr_review.py")
pr_review = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["pr_review"] = pr_review
spec.loader.exec_module(pr_review)


def _git(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args],
        cwd=repo,
        env=pr_review.isolated_git_env(),
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout.strip()


class ClassifyTierTest(unittest.TestCase):
    def test_exempt_tier_for_trusted_dependabot_minor_or_patch_bump(self):
        res = pr_review.classify_pr(
            number=10,
            title="chore(deps): bump collection from 1.18.0 to 1.19.0",
            author="dependabot[bot]",
            bot=True,
            author_association="NONE",
            head_sha="1111111",
            files=["pubspec.lock"],
            rollup="SUCCESS",
            history=[],
        )
        self.assertEqual(res.base_tier, "exempt")
        self.assertEqual(res.required_tier, "exempt")
        self.assertFalse(res.escalated)
        self.assertEqual(res.axes, [])
        self.assertEqual(res.recommended_models, [])

    def test_dependabot_major_bump_requires_deep_tier(self):
        res = pr_review.classify_pr(
            number=11,
            title="chore(deps): bump riverpod from 2.5.1 to 3.0.0",
            author="dependabot[bot]",
            bot=True,
            author_association="NONE",
            head_sha="2222222",
            files=["pubspec.yaml", "pubspec.lock"],
            rollup="SUCCESS",
            history=[],
        )
        self.assertEqual(res.base_tier, "deep")
        self.assertEqual(res.required_tier, "deep")
        self.assertIn("dependabot-major", res.risk_signatures)

    def test_fast_tier_for_localized_docs_or_tests(self):
        res = pr_review.classify_pr(
            number=12,
            title="docs: clarify quickstart instructions",
            author="owner",
            author_association="OWNER",
            head_sha="3333333",
            files=["docs/quickstart.md", "test/widget_test.dart"],
            additions=20,
            deletions=5,
            history=[],
        )
        self.assertEqual(res.base_tier, "fast")
        self.assertEqual(res.required_tier, "fast")
        self.assertEqual(res.axes, ["standards"])
        self.assertIn("gemini-3.8-flash", res.recommended_models)

    def test_balanced_tier_for_moderate_single_area_code_change(self):
        res = pr_review.classify_pr(
            number=13,
            title="feat(inventory): add expiry badge sorting",
            author="owner",
            author_association="OWNER",
            head_sha="4444444",
            files=[
                "lib/inventory/a.dart",
                "lib/inventory/b.dart",
                "lib/inventory/c.dart",
            ],
            additions=90,
            deletions=30,
            history=[],
        )
        self.assertEqual(res.base_tier, "balanced")
        self.assertEqual(res.required_tier, "balanced")
        self.assertEqual(res.axes, ["standards", "spec"])

    def test_deep_tier_for_workflows_policies_secrets_and_multi_area(self):
        wf = pr_review.classify_pr(
            number=14,
            title="ci: harden workflow permissions",
            author="owner",
            author_association="OWNER",
            head_sha="5555555",
            files=[".github/workflows/ci.yml"],
            history=[],
        )
        self.assertEqual(wf.required_tier, "deep")
        self.assertIn("workflow-ci", wf.risk_signatures)
        self.assertIn("actionlint", wf.recommended_static_checks)

        policy = pr_review.classify_pr(
            number=15,
            title="agents: update runner policy",
            author="owner",
            author_association="OWNER",
            head_sha="6666666",
            files=[".agents/policies/default.json"],
            history=[],
        )
        self.assertEqual(policy.required_tier, "deep")
        self.assertIn("agent-control-plane", policy.risk_signatures)

        multi = pr_review.classify_pr(
            number=16,
            title="feat: cross-area update",
            author="owner",
            author_association="OWNER",
            head_sha="7777777",
            files=["lib/inventory/item.dart", "packages/core/lib/core.dart"],
            additions=100,
            deletions=20,
            history=[],
        )
        self.assertEqual(multi.required_tier, "deep")
        self.assertIn("multi-area", multi.risk_signatures)

    def test_human_tier_for_one_way_door_fork_or_untrusted_author(self):
        one_way = pr_review.classify_pr(
            number=17,
            title="feat: production schema cutover",
            body="Summary\n**Door:** one-way\n",
            author="owner",
            author_association="OWNER",
            head_sha="8888888",
            files=["docs/guide.md"],
            history=[],
        )
        self.assertEqual(one_way.required_tier, "human")
        self.assertTrue(one_way.requires_human_approval)
        self.assertFalse(one_way.auto_merge_eligible)

        untrusted = pr_review.classify_pr(
            number=18,
            title="docs: fix typo",
            author="stranger",
            author_association="FIRST_TIME_CONTRIBUTOR",
            head_sha="9999999",
            files=["docs/guide.md"],
            history=[],
        )
        self.assertEqual(untrusted.required_tier, "human")
        self.assertFalse(untrusted.auto_merge_eligible)

    def test_history_escalation_elevates_tier_and_surfaces_static_checks(self):
        history = [
            {
                "type": "incident",
                "incident_id": "inc-abc123",
                "timestamp": "2026-11-21T10:00:00+00:00",
                "culprit_commit": "deadbeef1234567890",
                "pr": 99,
                "original_review_tier": "fast",
                "recommended_tier": "deep",
                "files": ["docs/architecture.md"],
                "areas": ["docs"],
                "risk_signatures": ["localized-docs-or-tests"],
                "recommended_static_checks": ["python3 scripts/docs/check_docs.py --strict"],
            }
        ]
        res = pr_review.classify_pr(
            number=19,
            title="docs: update architecture overview",
            author="owner",
            author_association="OWNER",
            head_sha="aaaaaaa",
            files=["docs/architecture.md"],
            history=history,
        )
        self.assertEqual(res.base_tier, "fast")
        self.assertEqual(res.required_tier, "deep")
        self.assertTrue(res.escalated)
        self.assertEqual(res.escalated_from, "fast")
        self.assertEqual(res.matching_incidents, ["inc-abc123"])
        self.assertIn("python3 scripts/docs/check_docs.py --strict", res.recommended_static_checks)
        self.assertTrue(any("inc-abc123" in r for r in res.escalation_reasons))


class PrepareReviewTest(unittest.TestCase):
    def test_deep_review_uses_highest_executable_tier(self):
        import agentctl

        specs = agentctl.provider_specs()
        claude = specs["claude"]
        claude["models"].pop("claude-opus-5-5")
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "workflow.json"
            path.write_text(pr_review.DEFAULT_WORKFLOW.read_text())
            args = argparse.Namespace(workflow=str(path), required_tier="deep", provider=["claude", "codex"])
            codex = agentctl.hu.HarnessUsageSnapshot(
                "codex", "ok", (agentctl.hu.UsageWindow("5h", "5h", 99),),
            )
            output = io.StringIO()
            with patch.object(agentctl, "provider_specs", return_value=specs), \
                 patch.object(agentctl, "available_providers", return_value=args.provider), \
                 patch.object(agentctl, "provider_is_safe", return_value=True), \
                 patch.object(agentctl.hu, "probe_all", return_value={"codex": codex}), \
                 contextlib.redirect_stdout(output):
                self.assertEqual(pr_review.cmd_prepare_review(args), 0)

            self.assertEqual(json.loads(output.getvalue()), {"tier": "balanced", "run_model": True})
            verify = json.loads(path.read_text())["steps"][-1]
            self.assertEqual(verify["tier"], "balanced")
            self.assertEqual(verify["providers"], ["claude"])
            self.assertEqual(verify["model"], "claude-sonnet-5-5")


class AttestationAndHistoryStoreTest(unittest.TestCase):
    def test_format_and_parse_attestation_round_trip(self):
        cls = pr_review.classify_pr(
            number=42,
            title="docs: add guide",
            author="owner",
            author_association="OWNER",
            head_sha="1234567890abcdef",
            files=["docs/guide.md"],
            history=[],
        )
        md = pr_review.format_review_markdown(
            classification=cls,
            status="approved",
            review_tier="deep",
            provider="claude",
            model="claude-opus-5-5",
            session_id="sess-42",
            summary="Dual-axis review passed.",
        )
        parsed = pr_review.parse_attestation(md)
        self.assertIsNotNone(parsed)
        assert parsed is not None
        self.assertEqual(parsed["pr"], 42)
        self.assertEqual(parsed["head_sha"], "1234567890abcdef")
        self.assertEqual(parsed["tier"], "deep")
        self.assertEqual(parsed["required_tier"], "fast")
        self.assertEqual(parsed["status"], "approved")
        self.assertEqual(parsed["provider"], "claude")
        self.assertEqual(parsed["model"], "claude-opus-5-5")
        self.assertEqual(parsed["session_id"], "sess-42")

    def test_cap_requires_a_trusted_head_bound_actions_attestation(self):
        marker = '<!-- agent-review: ' + json.dumps({
            "pr": 50, "head_sha": "abcdef123456", "status": "approved",
            "required_tier": "deep", "tier": "fast", "cap_reason": "provider-capacity",
        }) + ' -->'

        def approved(author, head="abcdef123456", required="deep"):
            return pr_review.evaluate_review_attestation(
                pr_number=50, head_sha=head, required_tier=required, owner="owner",
                comments=[{"body": marker, "author": author, "authorAssociation": "OWNER"}],
            )[0]

        actions = {"__typename": "Bot", "login": "github-actions[bot]"}
        self.assertTrue(approved(actions))
        self.assertFalse(approved(actions, head="123456abcdef"))
        self.assertFalse(approved(actions, required="human"))
        self.assertFalse(approved({"__typename": "User", "login": "owner"}))
        self.assertFalse(approved({"__typename": "Bot", "login": "dependabot[bot]"}))

    def test_evaluate_review_attestation_via_comment_review_and_history(self):
        marker = pr_review.format_attestation_marker(
            pr=50,
            head_sha="abcdef123456",
            tier="balanced",
            required_tier="balanced",
            status="approved",
        )
        # Comment from trusted bot satisfies balanced tier at exact head_sha
        ok, reason = pr_review.evaluate_review_attestation(
            pr_number=50,
            head_sha="abcdef123456",
            required_tier="balanced",
            comments=[{"body": f"Review summary\n\n{marker}", "author": {"__typename": "Bot", "login": "github-actions[bot]"}}],
        )
        self.assertTrue(ok)
        self.assertIsNone(reason)

        # Comment from untrusted user is ignored
        ok_untrusted, reason_untrusted = pr_review.evaluate_review_attestation(
            pr_number=50,
            head_sha="abcdef123456",
            required_tier="balanced",
            comments=[{"body": marker, "author": {"__typename": "User", "login": "stranger"}, "authorAssociation": "NONE"}],
            owner="owner",
        )
        self.assertFalse(ok_untrusted)
        self.assertIn("missing required balanced review", reason_untrusted or "")

        # Human tier requires formal human APPROVED review, not a bot comment
        ok_human_bot, reason_human_bot = pr_review.evaluate_review_attestation(
            pr_number=51,
            head_sha="abcdef123456",
            required_tier="human",
            comments=[{"body": marker, "author": {"__typename": "Bot", "login": "github-actions[bot]"}}],
            owner="owner",
        )
        self.assertFalse(ok_human_bot)
        self.assertIn("requires human APPROVED review", reason_human_bot or "")

        ok_human, _ = pr_review.evaluate_review_attestation(
            pr_number=51,
            head_sha="abcdef123456",
            required_tier="human",
            reviews=[
                {
                    "state": "APPROVED",
                    "author": "owner",
                    "bot": False,
                    "author_association": "OWNER",
                    "commit_oid": "abcdef123456",
                    "body": "LGTM",
                }
            ],
            owner="owner",
        )
        self.assertTrue(ok_human)

    def test_stage_pr_context_writes_snapshots_and_valid_workflow(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            cls = pr_review.classify_pr(
                number=77,
                title="feat: add review staging",
                author="owner",
                author_association="OWNER",
                head_sha="7777777abcdef",
                files=["scripts/github/pr_review.py"],
                history=[],
            )
            meta = {
                "number": 77,
                "title": "feat: add review staging",
                "body": "Implements staging",
                "author": "owner",
                "bot": False,
                "author_association": "OWNER",
                "draft": False,
                "fork": False,
                "head_sha": "7777777abcdef",
                "labels": ["merge/auto"],
                "files": ["scripts/github/pr_review.py"],
                "additions": 45,
                "deletions": 5,
                "changed_files": 1,
            }
            wf_out = tmp_path / "integrate-pr-77.json"
            staged = pr_review.stage_pr_context(
                pr_meta=meta,
                classification=cls,
                diff_text="@@ -1 +1 @@\n-old\n+new\n",
                state_dir=tmp_path,
                stage_workflow_out=wf_out,
            )
            self.assertTrue((tmp_path / "pr-77.json").is_file())
            self.assertTrue((tmp_path / "pr-77.md").is_file())
            self.assertTrue(wf_out.is_file())
            wf_data = json.loads(wf_out.read_text(encoding="utf-8"))
            self.assertEqual(wf_data["references"]["prs"], ["#77"])
            self.assertEqual(wf_data["steps"][1]["tier"], "deep")
            self.assertIn("pr_json", staged)


class InvestigateAndBisectLearnTest(unittest.TestCase):
    def test_dual_level_bisect_learn_and_investigate_on_temp_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            repo = tmp_path / "repo"
            repo.mkdir()
            history_path = tmp_path / "history.jsonl"
            sessions_path = tmp_path / "sessions.jsonl"
            ledger_path = tmp_path / "ledger.jsonl"

            _git(repo, "init", "-b", "main")
            _git(repo, "config", "user.name", "Test Owner")
            _git(repo, "config", "user.email", "owner@example.com")

            # Commit 1 (good base on main)
            (repo / "docs").mkdir()
            (repo / "docs/calc.txt").write_text("status=ok\n", encoding="utf-8")
            _git(repo, "add", "docs/calc.txt")
            _git(repo, "commit", "-m", "docs: initial status (#1)")
            good_sha = _git(repo, "rev-parse", "HEAD")

            # Feature branch for PR #2 with two commits: first clean, second introduces bug
            _git(repo, "checkout", "-b", "feat/pr-2")
            (repo / "docs/notes.md").write_text("# Notes\nAll good.\n", encoding="utf-8")
            _git(repo, "add", "docs/notes.md")
            _git(repo, "commit", "-m", "docs: add notes")

            (repo / "docs/calc.txt").write_text("status=broken\n", encoding="utf-8")
            _git(repo, "add", "docs/calc.txt")
            _git(repo, "commit", "-m", "docs: tweak calc status\n\nAgent-Session: sess-pr2")
            culprit_branch_sha = _git(repo, "rev-parse", "HEAD")

            # Merge PR #2 into main (--no-ff to create a real merge commit)
            _git(repo, "checkout", "main")
            _git(repo, "merge", "--no-ff", "feat/pr-2", "-m", "Merge pull request #2 from owner/feat/pr-2")
            merge_sha = _git(repo, "rev-parse", "HEAD")

            # Commit 3 on main (unrelated clean commit after merge)
            (repo / "docs/after.md").write_text("# After\n", encoding="utf-8")
            _git(repo, "add", "docs/after.md")
            _git(repo, "commit", "-m", "docs: post-merge doc (#3)")
            bad_sha = _git(repo, "rev-parse", "HEAD")

            # Seed review history showing PR #2 was originally reviewed at "fast" tier
            pr_review.append_history_record(
                {
                    "type": "review",
                    "timestamp": "2026-11-21T12:00:00+00:00",
                    "pr": 2,
                    "pr_ref": "#2",
                    "head_sha": culprit_branch_sha,
                    "author": "github-actions[bot]",
                    "bot": True,
                    "required_tier": "fast",
                    "review_tier": "fast",
                    "escalated": False,
                    "status": "approved",
                    "provider": "gemini",
                    "model": "gemini-3.8-flash",
                    "session_id": "sess-pr2",
                    "files": ["docs/calc.txt", "docs/notes.md"],
                    "areas": ["docs"],
                    "risk_signatures": ["localized-docs-or-tests"],
                    "summary": "Fast review approved PR #2",
                },
                history_path,
            )
            sessions_path.write_text(
                json.dumps(
                    {
                        "session_id": "sess-pr2",
                        "provider": "gemini",
                        "harness": "gemini",
                        "prs": ["#2"],
                        "commits": [culprit_branch_sha[:7]],
                        "summary": "Updated calc status",
                    },
                    sort_keys=True,
                )
                + "\n",
                encoding="utf-8",
            )
            ledger_path.write_text(
                json.dumps(
                    {
                        "event": "pr_merged",
                        "pr": "#2",
                        "commit": merge_sha[:7],
                    },
                    sort_keys=True,
                )
                + "\n",
                encoding="utf-8",
            )

            # Run dual-level bisect_learn: should identify merge_sha on first-parent and culprit_branch_sha on branch!
            test_cmd = "grep -q 'status=ok' docs/calc.txt"
            report = pr_review.bisect_learn(
                repo_root=repo,
                good_rev=good_sha,
                bad_rev=bad_sha,
                test_cmd=test_cmd,
                bisect_branch=True,
                first_parent=True,
                failure_signature="docs/calc.txt status corrupted",
                record=True,
                history_path=history_path,
                sessions_path=sessions_path,
            )

            self.assertEqual(report["merge_commit"], merge_sha)
            self.assertEqual(report["culprit_commit"], culprit_branch_sha)
            self.assertTrue(report["branch_bisected"])
            self.assertEqual(report["pr"], 2)
            self.assertEqual(report["original_review_tier"], "fast")
            self.assertEqual(report["recommended_tier"], "deep")
            self.assertIsNone(report["would_deeper_tier_catch"])
            self.assertIn("docs/calc.txt", report["files"])

            # Verify the incident was appended to history.jsonl and escalates future PRs touching docs/calc.txt
            follow_up = pr_review.classify_pr(
                number=4,
                title="docs: update calc.txt",
                author="owner",
                author_association="OWNER",
                head_sha="eeeeeee",
                files=["docs/calc.txt"],
                history_path=history_path,
            )
            self.assertEqual(follow_up.base_tier, "fast")
            self.assertEqual(follow_up.required_tier, "deep")
            self.assertTrue(follow_up.escalated)
            self.assertIn(test_cmd, follow_up.recommended_static_checks)

            # Verify investigate correlates git commits, PR #2, session sess-pr2, review history, and incident
            inv = pr_review.investigate(
                repo_root=repo,
                rev_range=f"{good_sha}..{bad_sha}",
                paths=["docs/calc.txt"],
                pr_filter=2,
                history_path=history_path,
                sessions_path=sessions_path,
                ledger_path=ledger_path,
            )
            self.assertEqual(len(inv["merged_prs"]), 1)
            self.assertEqual(inv["merged_prs"][0]["pr"], 2)
            self.assertEqual(inv["merged_prs"][0]["review_tier"], "fast")
            self.assertIn("sess-pr2", inv["merged_prs"][0]["session_ids"])
            self.assertEqual(len(inv["incidents"]), 1)
            self.assertEqual(inv["incidents"][0]["culprit_commit"], culprit_branch_sha)


class HardeningTest(unittest.TestCase):
    def _marker(self, head: str, tier: str = "deep") -> str:
        return f'<!-- agent-review: {{"pr": 5, "head_sha": "{head}", "tier": "{tier}", "status": "approved"}} -->'

    def _evaluate(self, comment_author: str, pr_author: str, history=None):
        return pr_review.evaluate_review_attestation(
            pr_number=5,
            head_sha="abc1234",
            required_tier="deep",
            comments=[{
                "author": {"login": comment_author, "__typename": "Bot"},
                "authorAssociation": "NONE",
                "body": self._marker("abc1234"),
            }],
            history=history,
            owner="owner",
            pr_author=pr_author,
        )

    def test_pr_author_cannot_self_attest(self):
        ok, _ = self._evaluate("github-actions[bot]", "github-actions")
        self.assertFalse(ok)
        ok, _ = self._evaluate("github-actions[bot]", "owner")
        self.assertTrue(ok)

    def test_history_is_not_an_attestation_source(self):
        forged = [{"type": "review", "pr": 5, "head_sha": "abc1234", "review_tier": "deep", "status": "approved"}]
        ok, _ = pr_review.evaluate_review_attestation(
            pr_number=5, head_sha="abc1234", required_tier="deep", history=forged, owner="owner",
        )
        self.assertFalse(ok)

    def test_history_and_reviews_paths_are_critical(self):
        self.assertTrue(pr_review.is_critical_path(".agents/reviews/history.jsonl"))
        self.assertTrue(pr_review.is_critical_path(".agents/workflows/integrate-pr.json"))

    def test_load_history_skips_blank_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "h.jsonl"
            path.write_text('{"type": "review"}\n\n{"type": "incident"}\n', encoding="utf-8")
            self.assertEqual(len(pr_review.load_history(path)), 2)

    def test_same_commit_requires_seven_chars(self):
        self.assertFalse(pr_review._same_commit("", "abcdef1234"))
        self.assertFalse(pr_review._same_commit("abc", "abcdef1234"))
        self.assertTrue(pr_review._same_commit("abcdef1", "abcdef1234"))

    def test_issue_references_are_not_prs(self):
        self.assertIsNone(pr_review.PR_NUMBER_RE.search("fixes #303"))
        self.assertIsNotNone(pr_review.PR_NUMBER_RE.search("feat: x (#12)"))

    def test_extract_verdict_uses_last_verdict_in_verify_gate_artifact(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "verify-gate.attempt-1.json").write_text("VERDICT: CHANGES_REQUESTED ... VERDICT: APPROVE", encoding="utf-8")
            (root / "assess-readiness.attempt-1.json").write_text("VERDICT: CHANGES_REQUESTED", encoding="utf-8")
            result = {"artifacts": ["verify-gate.attempt-1.json", "assess-readiness.attempt-1.json"]}
            self.assertEqual(pr_review.extract_verdict(result, root), "APPROVE")
            self.assertIsNone(pr_review.extract_verdict({"artifacts": []}, root))


if __name__ == "__main__":
    unittest.main()
