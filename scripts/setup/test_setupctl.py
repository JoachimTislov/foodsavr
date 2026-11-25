#!/usr/bin/env python3
"""Offline unit tests for scripts/setup/setupctl.py (ADR 0008)."""

from __future__ import annotations

from contextlib import redirect_stderr, redirect_stdout
from io import StringIO

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
        probe["github"]["event_policy"] = {"state": "match", "policy_id": 7, "detail": "matches"}
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
        clean_env = {k: v for k, v in os.environ.items() if k not in setupctl.AGENT_ENV_VARS}
        with patch.dict(os.environ, {**clean_env, "AGENT_SESSION_ID": "test:123"}, clear=True):
            with self.assertRaises(PermissionError):
                setupctl.enable_actions(repo="alice/foodsavr", dry_run=False)

        with patch.dict(os.environ, clean_env, clear=True):
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

    def test_interactive_mutations_keep_json_stdout_clean(self):
        cases = (
            ("ensure-branches", "ensure_branches", {"created": ["stable"]}, "Create stable"),
            ("fork", "fork_repository", {"fork": "alice/foodsavr"}, "Fork"),
            ("enable-actions", "enable_actions", {"already_enabled": False}, "Enable GitHub Actions"),
        )
        for command, method, result, prompt in cases:
            with self.subTest(command=command):
                out, err = StringIO(), StringIO()
                with (
                    patch.object(setupctl, "is_unattended_agent_env", return_value=False),
                    patch.object(setupctl, "resolve_repo", return_value="alice/foodsavr"),
                    patch.object(setupctl, "resolve_upstream", return_value="owner/foodsavr"),
                    patch.object(setupctl, "resolve_topology", return_value="two-stage"),
                    patch.object(setupctl, method, return_value=result),
                    patch.object(setupctl.sys.stdin, "isatty", return_value=True),
                    patch("builtins.input", return_value="y"),
                    redirect_stdout(out),
                    redirect_stderr(err),
                ):
                    self.assertEqual(setupctl.main([command, "-o", "json"]), 0)
                self.assertEqual(json.loads(out.getvalue()), result)
                self.assertIn(prompt, err.getvalue())
                if command == "ensure-branches":
                    self.assertIn("missing stable", err.getvalue())


def _policy_json(**over):
    return setupctl.desired_event_policy() | {"id": 7} | over


def _policy_summary(**over):
    # The list endpoint returns summaries without `conditions` or `rules`.
    return {"id": 7, "name": setupctl.EVENT_POLICY_NAME, "enforcement": "active"} | over


def _listing(policy):
    """`_run` side effect: summary list first, then the per-ID detail."""
    summary = _policy_summary(**{k: v for k, v in policy.items() if k in ("id", "enforcement")})
    return [_cp(json.dumps([summary])), _cp(json.dumps(policy))]


def _cp(out="", code=0, err=""):
    return subprocess.CompletedProcess([], code, out, err)


class EventPolicyTest(unittest.TestCase):
    def _read(self, *procs):
        with patch.object(setupctl, "_run", side_effect=list(procs)) as mock_run:
            result = setupctl.read_event_policy("alice/foodsavr")
        return result, [c.args[0][2] for c in mock_run.call_args_list]

    def test_read_states(self):
        res, paths = self._read(*_listing(_policy_json()))
        self.assertEqual(res["state"], "match")
        self.assertEqual(paths, ["repos/alice/foodsavr/actions/policies?per_page=100&has_parents=false", "repos/alice/foodsavr/actions/policies/7"])
        # The named policy on a later page is still found (slurped pages, list or object shaped).
        other = {"id": 3, "name": "other", "enforcement": "active"}
        for pages in ([[other], [_policy_summary()]], [{"policies": [other]}, {"policies": [_policy_summary()]}]):
            with self.subTest(pages=pages):
                self.assertEqual(self._read(_cp(json.dumps(pages)), _cp(json.dumps(_policy_json())))[0]["state"], "match")
        self.assertEqual(self._read(_cp("[]"))[0]["state"], "missing")
        actor_rule = {"type": "restrict_actions_actors", "parameters": {"allowed_actors": ["alice"]}}
        extra = _policy_json(rules=[*setupctl.desired_event_policy()["rules"], actor_rule])
        self.assertEqual(self._read(*_listing(extra))[0]["state"], "mismatch")
        wrong = _policy_json(conditions={"workflow_path": {"include": ["~ALL"], "exclude": []}})
        self.assertEqual(self._read(*_listing(wrong))[0]["state"], "mismatch")
        self.assertEqual(self._read(_cp(code=1, err="HTTP 404"))[0]["state"], "unavailable")
        self.assertEqual(self._read(_cp("not json"))[0]["state"], "unavailable")
        summary = _cp(json.dumps([_policy_summary()]))
        self.assertEqual(self._read(summary, _cp(code=1, err="HTTP 403"))[0]["state"], "unavailable")
        self.assertEqual(self._read(summary, _cp("not json"))[0]["state"], "unavailable")
        # A summary alone (no id to fetch the detail) never reads as a match.
        idless = {k: v for k, v in _policy_summary().items() if k != "id"}
        self.assertEqual(self._read(_cp(json.dumps([idless])))[0]["state"], "mismatch")

    def test_verify_reports_match_mismatch_and_unavailable(self):
        for state, ok in (("match", True), ("mismatch", False), ("missing", False), ("unavailable", False)):
            with self.subTest(state=state):
                probe = _sample_probe(repo="alice/foodsavr", login="alice", is_admin=True, local_ok=True)
                probe["github"]["event_policy"] = {"state": state, "policy_id": None, "detail": state}
                checks = {c["name"]: c for c in setupctl.verify_profile(probe, profile="fork-agents")["checks"]}
                self.assertEqual(checks["actions-event-policy"]["ok"], ok)
                if not ok:
                    self.assertIn("make setup-event-policy REPO=alice/foodsavr", checks["actions-event-policy"]["remediation"])

    def test_verify_fails_when_policy_was_not_probed(self):
        probe = _sample_probe(repo="alice/foodsavr", login="alice", is_admin=False, local_ok=True)
        probe["github"]["event_policy"] = None
        checks = {c["name"]: c for c in setupctl.verify_profile(probe, profile="fork-agents")["checks"]}
        self.assertFalse(checks["actions-event-policy"]["ok"])
        self.assertIn("not probed", checks["actions-event-policy"]["detail"])

    def test_plan_lists_owner_action_until_matched(self):
        probe = _sample_probe(repo="alice/foodsavr", login="alice", is_admin=True, local_ok=True)
        probe["github"]["event_policy"] = {"state": "missing"}
        plan = setupctl.build_plan(probe, profile="fork-agents", topology="single")
        action = next(a for a in plan["human_actions"] if a["id"] == "apply-event-policy")
        self.assertEqual(action["command"], "make setup-event-policy REPO=alice/foodsavr")
        probe["github"]["event_policy"] = {"state": "match"}
        plan = setupctl.build_plan(probe, profile="fork-agents", topology="single")
        self.assertNotIn("apply-event-policy", [a["id"] for a in plan["human_actions"]])

    def test_allowed_events_cover_every_trigger_of_the_targeted_workflows(self):
        # A too-narrow allowed_events silently stops the omitted triggers of targeted files.
        for rel in setupctl.EVENT_POLICY_WORKFLOWS:
            with self.subTest(workflow=rel):
                lines = (ROOT / rel).read_text(encoding="utf-8").splitlines()
                start = next(i for i, line in enumerate(lines) if line.rstrip() in ("on:", '"on":', "'on':"))
                triggers = set()
                for line in lines[start + 1:]:
                    if line and not line[0].isspace():
                        break
                    stripped = line.strip()
                    if line.startswith("  ") and not line.startswith("   ") and stripped.endswith(":") and not stripped.startswith("#"):
                        triggers.add(stripped[:-1])
                self.assertTrue(triggers)
                self.assertLessEqual(triggers, set(setupctl.EVENT_POLICY_EVENTS))

    def test_apply_guard_idempotence_create_and_update(self):
        clean = {k: v for k, v in os.environ.items() if k not in setupctl.AGENT_ENV_VARS}
        with patch.dict(os.environ, {**clean, "AGENT_SESSION_ID": "t:1"}, clear=True):
            with self.assertRaises(PermissionError):
                setupctl.apply_event_policy(repo="alice/foodsavr")
        with patch.dict(os.environ, clean, clear=True):
            with patch.object(setupctl, "_run", side_effect=_listing(_policy_json())):
                with patch.object(setupctl.subprocess, "run") as mock_write:
                    res = setupctl.apply_event_policy(repo="alice/foodsavr")
                mock_write.assert_not_called()
            self.assertTrue(res["already_applied"])

            for listing, method, path in (
                ([_cp("[]")], "POST", "repos/alice/foodsavr/actions/policies"),
                (_listing(_policy_json(enforcement="evaluate")), "PUT", "repos/alice/foodsavr/actions/policies/7"),
            ):
                with patch.object(setupctl, "_run", side_effect=listing):
                    with patch.object(setupctl.subprocess, "run", return_value=_cp()) as mock_write:
                        res = setupctl.apply_event_policy(repo="alice/foodsavr")
                argv = mock_write.call_args.args[0]
                self.assertEqual((argv[3], argv[4]), (method, path))
                self.assertEqual(json.loads(mock_write.call_args.kwargs["input"]), setupctl.desired_event_policy())
                self.assertFalse(res["already_applied"])

            with patch.object(setupctl, "_run", return_value=_cp(code=1, err="HTTP 404")):
                with self.assertRaises(RuntimeError):
                    setupctl.apply_event_policy(repo="alice/foodsavr")
            idless = {k: v for k, v in _policy_json(enforcement="evaluate").items() if k != "id"}
            with patch.object(setupctl, "_run", return_value=_cp(json.dumps([idless]))):
                with patch.object(setupctl.subprocess, "run") as mock_write:
                    with self.assertRaises(RuntimeError):
                        setupctl.apply_event_policy(repo="alice/foodsavr")
                mock_write.assert_not_called()
            with patch.object(setupctl, "_run", return_value=_cp("[]")):
                with patch.object(setupctl.subprocess, "run") as mock_write:
                    res = setupctl.apply_event_policy(repo="alice/foodsavr", dry_run=True)
                mock_write.assert_not_called()
            self.assertEqual(res["state"], "missing")


if __name__ == "__main__":
    unittest.main()
