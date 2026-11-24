#!/usr/bin/env python3
"""Offline unit tests for scripts/setup/setupctl.py (ADR 0008)."""

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("setupctl", ROOT / "scripts/setup/setupctl.py")
setupctl = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules["setupctl"] = setupctl
spec.loader.exec_module(setupctl)


def _sample_probe(
    *,
    repo: str = "JoachimTislov/foodsavr",
    login: str = "contributor",
    is_admin: bool = False,
    private: bool = False,
    rulesets_supported: bool = True,
    branches: list[str] | None = None,
    variables: dict[str, str] | None = None,
    secret_names: list[str] | None = None,
    local_ok: bool = False,
) -> dict:
    return {
        "schema_version": 1,
        "root": "/tmp/repo",
        "tools": {
            "git": True,
            "gh": True,
            "terraform": True,
            "flutter": True,
            "dart": True,
            "gcloud": True,
            "python3": True,
            "claude": True,
            "codex": False,
            "agy": False,
        },
        "remotes": {"origin": f"https://github.com/{repo}.git"},
        "origin_repo": repo,
        "upstream_repo": None,
        "local_config": {},
        "local_files": {
            "dotenv": local_ok,
            "google_services": local_ok,
            "instance_local": local_ok,
            "hooks_configured": local_ok,
        },
        "github": {
            "authenticated": bool(login),
            "login": login,
            "target_repo": repo,
            "repo_accessible": True,
            "is_admin": is_admin,
            "private": private,
            "default_branch": "develop",
            "rulesets_supported": rulesets_supported,
            "needs_fork": not is_admin,
            "branches": branches if branches is not None else ["develop"],
            "variables": variables or {},
            "secret_names": secret_names or [],
        },
        "recommendations": {
            "default_topology": "full-channels" if (repo == setupctl.UPSTREAM_REPO and is_admin) else "single",
            "enable_rulesets": rulesets_supported,
        },
    }


class ParseAndScaffoldTest(unittest.TestCase):
    def test_parse_github_repo_supports_https_and_ssh(self):
        self.assertEqual(setupctl.parse_github_repo("https://github.com/alice/foodsavr.git"), "alice/foodsavr")
        self.assertEqual(setupctl.parse_github_repo("git@github.com:alice/foodsavr.git"), "alice/foodsavr")
        self.assertEqual(setupctl.parse_github_repo("ssh://git@github.com/alice/foodsavr"), "alice/foodsavr")
        self.assertIsNone(setupctl.parse_github_repo("https://gitlab.com/alice/foodsavr.git"))

    def test_scaffold_local_is_idempotent_and_preserves_existing_files(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)

            first = setupctl.scaffold_local(root=root, profile="local-dev", topology="single", repo="alice/foodsavr")
            self.assertEqual(
                sorted(first["created"]),
                ["android/app/google-services.json", "assets/.env"],
            )
            self.assertTrue(first["hooks_configured"])
            self.assertEqual(first["instance_local"], ".agents/instance.local.json")

            # Custom edit should not be clobbered on re-run without --force.
            (root / "assets/.env").write_text("CUSTOM_KEY=1\n", encoding="utf-8")
            second = setupctl.scaffold_local(root=root, profile="local-dev", topology="single", repo="alice/foodsavr")
            self.assertEqual(second["created"], [])
            self.assertEqual(len(second["skipped"]), 2)
            self.assertEqual((root / "assets/.env").read_text(encoding="utf-8"), "CUSTOM_KEY=1\n")


class PlanAndVerifyTest(unittest.TestCase):
    def test_local_dev_requires_zero_human_cloud_steps(self):
        probe = _sample_probe(is_admin=False, local_ok=False)
        plan = setupctl.build_plan(probe, profile="local-dev")
        self.assertFalse(plan["needs_fork"])
        self.assertEqual(plan["human_actions"], [])
        self.assertEqual([a["id"] for a in plan["agent_actions"]], ["scaffold-local"])

    def test_non_owner_fork_agents_plan_includes_fork_and_enable_actions_last(self):
        probe = _sample_probe(repo="JoachimTislov/foodsavr", login="alice", is_admin=False, rulesets_supported=False)
        with tempfile.TemporaryDirectory() as td:
            plan = setupctl.build_plan(probe, profile="fork-agents", topology="single", write_dir=Path(td))
            self.assertTrue(plan["needs_fork"])
            self.assertEqual(plan["target_repo"], "alice/foodsavr")
            self.assertFalse(plan["enable_rulesets"])
            human_ids = [a["id"] for a in plan["human_actions"]]
            self.assertEqual(human_ids[0], "fork-repo")
            self.assertEqual(human_ids[-1], "enable-actions")
            self.assertIn("create-agent-app", human_ids)
            self.assertIn("create-release-gate-app", human_ids)
            self.assertIn("apply-github-terraform", human_ids)
            tfvars = (Path(td) / "github.tfvars").read_text(encoding="utf-8")
            self.assertIn('github_owner        = "alice"', tfvars)
            self.assertIn('release_topology    = "single"', tfvars)
            self.assertIn("enable_rulesets     = false", tfvars)

    def test_full_cloud_plan_includes_gcp_without_firebase_options_secret(self):
        probe = _sample_probe(
            repo="alice/foodsavr",
            login="alice",
            is_admin=True,
            branches=list(setupctl.TOPOLOGY_BRANCHES["two-stage"]),
            variables={"AGENT_APP_ID": "111", "RELEASE_GATE_APP_ID": "222"},
            secret_names=["AGENT_APP_PRIVATE_KEY", "RELEASE_GATE_APP_PRIVATE_KEY", "CLAUDE_CODE_OAUTH_TOKEN"],
            local_ok=True,
        )
        plan = setupctl.build_plan(probe, profile="full-cloud", topology="two-stage", firebase_plan="spark")
        self.assertFalse(plan["needs_fork"])
        human_ids = [a["id"] for a in plan["human_actions"]]
        self.assertNotIn("fork-repo", human_ids)
        self.assertNotIn("create-agent-app", human_ids)
        self.assertIn("apply-gcp-terraform", human_ids)
        self.assertNotIn("sync-firebase-options", human_ids)

    def test_verify_profile_passes_when_requirements_met(self):
        probe = _sample_probe(
            repo="alice/foodsavr",
            login="alice",
            is_admin=True,
            branches=["develop"],
            variables={
                "RELEASE_TOPOLOGY": "single",
                "AGENT_APP_ID": "111",
                "RELEASE_GATE_APP_ID": "222",
                "GCP_WORKLOAD_IDENTITY_PROVIDER": "projects/1/locations/global/workloadIdentityPools/github/providers/github-oidc",
                "GCP_DEPLOY_SERVICE_ACCOUNT": "github-deploy-live@p.iam.gserviceaccount.com",
            },
            secret_names=["AGENT_APP_PRIVATE_KEY", "RELEASE_GATE_APP_PRIVATE_KEY", "CODEX_AUTH_JSON_B64"],
            local_ok=True,
        )
        self.assertTrue(setupctl.verify_profile(probe, profile="local-dev")["ready"])
        self.assertTrue(setupctl.verify_profile(probe, profile="fork-agents")["ready"])
        self.assertTrue(setupctl.verify_profile(probe, profile="full-cloud")["ready"])


class MutationGuardTest(unittest.TestCase):
    def test_ensure_branches_and_fork_refuse_unattended_agent_env(self):
        with patch.dict(os.environ, {"AGENT_SESSION_ID": "test:123"}, clear=False):
            with self.assertRaises(PermissionError):
                setupctl.ensure_branches(repo="alice/foodsavr", topology="two-stage", dry_run=False)
            with self.assertRaises(PermissionError):
                setupctl.fork_repository(upstream="JoachimTislov/foodsavr", dry_run=False)

    def test_ensure_branches_dry_run_creates_only_missing_and_never_deletes(self):
        def fake_run(argv, **kwargs):
            if "git/ref/heads/develop" in " ".join(argv):
                return subprocess.CompletedProcess(argv, 0, "develop-sha\n", "")
            if "branches?per_page=100" in " ".join(argv):
                return subprocess.CompletedProcess(argv, 0, "develop\tdevelop-sha\nnightly\tnightly-sha\nbeta\tbeta-sha\nstable\tstable-sha\nrelease\trelease-sha\n", "")
            if "compare/" in " ".join(argv):
                state = "behind" if "stable-sha...beta-sha" in " ".join(argv) else "ahead"
                return subprocess.CompletedProcess(argv, 0, state + "\n", "")
            raise AssertionError(f"Unexpected mutating call: {argv}")

        with patch.object(setupctl, "_run", side_effect=fake_run):
            res = setupctl.ensure_branches(repo="alice/foodsavr", topology="full-channels", dry_run=True)
        self.assertEqual(res["created"], ["daily", "weekly"])
        self.assertEqual(res["already_present"], ["stable"])
        self.assertEqual(res["seeds"], {
            "daily": {"source": "nightly", "sha": "nightly-sha"},
            "weekly": {"source": "develop", "sha": "develop-sha"},
        })
        self.assertEqual(res["legacy_present"], ["beta", "nightly", "release"])


    def test_ensure_branches_falls_back_when_legacy_seeds_diverge(self):
        def fake_run(argv, **kwargs):
            endpoint = " ".join(argv)
            if "git/ref/heads/develop" in endpoint:
                out = "develop-sha"
            elif "branches?per_page=100" in endpoint:
                out = "develop\tdevelop-sha\nnightly\tnightly-sha\nbeta\tbeta-sha"
            elif "compare/" in endpoint:
                out = "diverged" if "nightly-sha...beta-sha" in endpoint else "ahead"
            else:
                raise AssertionError(f"Unexpected mutating call: {argv}")
            return subprocess.CompletedProcess(argv, 0, out + "\n", "")

        with patch.object(setupctl, "_run", side_effect=fake_run):
            result = setupctl.ensure_branches(repo="alice/foodsavr", topology="full-channels", dry_run=True)
        self.assertEqual(result["seeds"], {
            "daily": {"source": "nightly", "sha": "nightly-sha"},
            "weekly": {"source": "develop", "sha": "develop-sha"},
            "stable": {"source": "weekly", "sha": "develop-sha"},
        })


class ZeroArgDefaultsAndCliTest(unittest.TestCase):
    def test_resolve_repo_prefers_explicit_then_origin_then_instance_local(self):
        self.assertEqual(setupctl.resolve_repo("bob/foodsavr"), "bob/foodsavr")
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            with patch.object(setupctl, "detect_git_remotes", return_value={"origin": "git@github.com:alice/foodsavr.git"}):
                self.assertEqual(setupctl.resolve_repo(root=root), "alice/foodsavr")

            with patch.object(setupctl, "detect_git_remotes", return_value={}):
                with self.assertRaises(ValueError):
                    setupctl.resolve_repo(root=root)
                setupctl.save_instance_local({"repo": "carol/foodsavr"}, root=root)
                self.assertEqual(setupctl.resolve_repo(root=root), "carol/foodsavr")

    def test_resolve_topology_reads_repo_variable_and_defaults_to_full_channels(self):
        self.assertEqual(setupctl.resolve_topology("alice/foodsavr", "two-stage"), "two-stage")
        with patch.object(
            setupctl,
            "_run",
            return_value=subprocess.CompletedProcess([], 0, "two-stage\n", ""),
        ):
            self.assertEqual(setupctl.resolve_topology("alice/foodsavr"), "two-stage")
        with patch.object(
            setupctl,
            "_run",
            return_value=subprocess.CompletedProcess([], 1, "", "404 Not Found"),
        ):
            self.assertEqual(setupctl.resolve_topology("alice/foodsavr"), "full-channels")

    def test_resolve_upstream_checks_remote_then_github_parent_then_default(self):
        self.assertEqual(setupctl.resolve_upstream("org/foodsavr"), "org/foodsavr")
        with patch.object(
            setupctl,
            "detect_git_remotes",
            return_value={"upstream": "https://github.com/org/foodsavr.git", "origin": "https://github.com/alice/foodsavr.git"},
        ):
            self.assertEqual(setupctl.resolve_upstream(), "org/foodsavr")

        with (
            patch.object(setupctl, "detect_git_remotes", return_value={"origin": "https://github.com/alice/foodsavr.git"}),
            patch.object(setupctl, "_run", return_value=subprocess.CompletedProcess([], 0, "parent-org/foodsavr\n", "")),
        ):
            self.assertEqual(setupctl.resolve_upstream(), "parent-org/foodsavr")

        with (
            patch.object(setupctl, "detect_git_remotes", return_value={}),
        ):
            self.assertEqual(setupctl.resolve_upstream(), setupctl.UPSTREAM_REPO)

    def test_enable_actions_is_idempotent_and_respects_agent_guard(self):
        with patch.dict(os.environ, {"AGENT_SESSION_ID": "test:123"}, clear=False):
            with self.assertRaises(PermissionError):
                setupctl.enable_actions(repo="alice/foodsavr", dry_run=False)

        with patch.object(
            setupctl,
            "_run",
            return_value=subprocess.CompletedProcess([], 0, "true\n", ""),
        ) as mock_run:
            res = setupctl.enable_actions(repo="alice/foodsavr", dry_run=False)
        self.assertTrue(res["already_enabled"])
        self.assertEqual(mock_run.call_count, 1)

        with patch.object(
            setupctl,
            "_run",
            side_effect=[
                subprocess.CompletedProcess([], 0, "false\n", ""),
                subprocess.CompletedProcess([], 0, "", ""),
            ],
        ) as mock_run:
            res = setupctl.enable_actions(repo="alice/foodsavr", dry_run=False)
        self.assertFalse(res["already_enabled"])
        self.assertEqual(mock_run.call_count, 2)
        self.assertIn("-X", mock_run.call_args_list[1].args[0])

    def test_cli_ensure_branches_zero_args_interactive_and_concise_output(self):
        from contextlib import redirect_stderr, redirect_stdout
        from io import StringIO

        clean_env = {k: v for k, v in os.environ.items() if k not in setupctl.AGENT_ENV_VARS}
        # Non-TTY without --yes fails cleanly with exit 2.
        err = StringIO()
        with (
            patch.dict(os.environ, clean_env, clear=True),
            patch.object(setupctl, "resolve_repo", return_value="alice/foodsavr"),
            patch.object(setupctl, "resolve_topology", return_value="full-channels"),
            patch.object(setupctl.sys.stdin, "isatty", return_value=False),
            redirect_stderr(err),
        ):
            code = setupctl.main(["ensure-branches"])
        self.assertEqual(code, 2)
        self.assertIn("--yes", err.getvalue())

        # Interactive TTY prompts once and prints concise summary without raw dict/SHAs.
        out = StringIO()
        fake_branches = [
            {
                "repo": "alice/foodsavr",
                "topology": "full-channels",
                "base_branch": "develop",
                "base_sha": "abc1234",
                "created": ["daily", "weekly", "stable"],
                "already_present": [],
                "seeds": {
                    "daily": {"source": "develop", "sha": "abc1234"},
                    "weekly": {"source": "develop", "sha": "abc1234"},
                    "stable": {"source": "weekly", "sha": "abc1234"},
                },
                "legacy_present": [],
                "dry_run": True,
            },
            {
                "repo": "alice/foodsavr",
                "topology": "full-channels",
                "base_branch": "develop",
                "base_sha": "abc1234",
                "created": ["daily", "weekly", "stable"],
                "already_present": [],
                "seeds": {
                    "daily": {"source": "develop", "sha": "abc1234"},
                    "weekly": {"source": "develop", "sha": "abc1234"},
                    "stable": {"source": "weekly", "sha": "abc1234"},
                },
                "legacy_present": [],
                "dry_run": False,
            },
        ]
        with (
            patch.dict(os.environ, clean_env, clear=True),
            patch.object(setupctl, "resolve_repo", return_value="alice/foodsavr"),
            patch.object(setupctl, "resolve_topology", return_value="full-channels"),
            patch.object(setupctl.sys.stdin, "isatty", return_value=True),
            patch.object(setupctl, "ensure_branches", side_effect=fake_branches),
            patch("builtins.input", return_value="y"),
            redirect_stdout(out),
        ):
            code = setupctl.main(["ensure-branches"])
        self.assertEqual(code, 0)
        text = out.getvalue()
        self.assertIn("alice/foodsavr (full-channels): missing daily, weekly, stable", text)
        self.assertIn("alice/foodsavr (full-channels): Created daily (from develop), weekly (from develop), stable (from weekly)", text)
        self.assertNotIn("abc1234", text)
        self.assertNotIn("{", text)


if __name__ == "__main__":
    unittest.main()
