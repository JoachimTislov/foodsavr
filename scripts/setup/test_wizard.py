from argparse import Namespace
from contextlib import redirect_stderr, redirect_stdout
from io import BytesIO, StringIO
import json
import os
from pathlib import Path
import tempfile
from unittest import TestCase
from unittest.mock import Mock, patch
from urllib.error import HTTPError

from app_names import app_name
import wizard


class WizardTest(TestCase):
    def test_list_only_reports_incomplete_steps(self):
        action = Mock()
        verify = Mock()
        output = StringIO()
        with redirect_stdout(output):
            wizard.process(wizard.Step("GitHub sign-in", True, action), True, verify)
            wizard.process(wizard.Step("GitHub configuration", False, action), True, verify)
        self.assertEqual(output.getvalue(), "GitHub configuration\n")
        action.assert_not_called()
        verify.assert_not_called()

    def test_resuming_local_setup_reuses_existing_configuration(self):
        state = {
            "local_config": {"profile": "local-dev", "repo": "owner/repo", "release_topology": "single"},
            "local_files": {"hooks_configured": True, "instance_local": True},
            "tools": {"flutter": True},
            "github": {"target_repo": "owner/repo"},
        }
        output = StringIO()
        args = Namespace(repo=None, profile="local-dev", list=False)
        with patch.object(wizard, "probe_environment", return_value=state), patch.object(
            wizard, "scaffold_local"
        ) as scaffold, redirect_stdout(output):
            self.assertEqual(wizard.setup(args, False), 0)
        self.assertEqual(output.getvalue(), "Local development files ready.\n")
        scaffold.assert_not_called()

    def test_terraform_listing_only_plans(self):
        output = StringIO()
        with patch.object(wizard, "run", return_value=2) as run, redirect_stdout(output):
            self.assertTrue(wizard.terraform_step("GitHub configuration", "git.sh", {}, True, True))
        self.assertEqual(output.getvalue(), "GitHub configuration\n")
        self.assertEqual(run.call_args.args, ("git.sh", "plan"))

    def test_terraform_step_without_prerequisites_is_pending(self):
        for listing in (False, True):
            with self.subTest(listing=listing):
                output, errors = StringIO(), StringIO()
                with (
                    patch.object(wizard, "run") as run,
                    redirect_stdout(output),
                    redirect_stderr(errors),
                ):
                    self.assertEqual(
                        wizard.terraform_step("GitHub configuration", "git.sh", {}, listing, False), listing
                    )
                run.assert_not_called()
                if listing:
                    self.assertEqual(output.getvalue(), "GitHub configuration\n")
                else:
                    self.assertIn("GitHub configuration pending.", errors.getvalue())

    def test_owner_names_omit_username_and_truncation_preserves_role(self):
        self.assertEqual(app_name("JoachimTislov/foodsavr", "release-gate"), "foodsavr-release-gate")
        repo = "long-owner-for-fork/long-name-for-a-fork-of-foodsavr"
        name = app_name(repo, "release-gate", owner_suffix=True)
        self.assertLessEqual(len(name), 34)
        self.assertTrue(name.endswith("-release-gate-long-own"))

    def test_enable_facebook_provider_creates_when_missing_and_patches_when_present(self):
        with patch.object(wizard, "identity_toolkit_token", return_value="tok"):
            not_found = HTTPError("u", 404, "missing", {}, BytesIO(b"{}"))
            with patch.object(
                wizard,
                "urlopen",
                side_effect=[not_found, BytesIO(b'{"enabled": true}')],
            ) as mock_open:
                self.assertTrue(wizard.enable_facebook_provider("proj", None, "app1", "sec1"))
            self.assertEqual(mock_open.call_count, 2)
            req_post = mock_open.call_args_list[1].args[0]
            self.assertEqual(req_post.get_method(), "POST")
            self.assertIn("idpId=facebook.com", req_post.full_url)
            self.assertEqual(
                json.loads(req_post.data.decode()),
                {"enabled": True, "clientId": "app1", "clientSecret": "sec1"},
            )

            with patch.object(
                wizard,
                "urlopen",
                side_effect=[BytesIO(b'{"enabled": false}'), BytesIO(b'{"enabled": true}')],
            ) as mock_open:
                self.assertTrue(wizard.enable_facebook_provider("proj", None, "app1", "sec1"))
            req_patch = mock_open.call_args_list[1].args[0]
            self.assertEqual(req_patch.get_method(), "PATCH")
            self.assertIn("updateMask=enabled,clientId,clientSecret", req_patch.full_url)

    def test_facebook_sign_in_uses_dotenv_credentials_via_api(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".env").write_text("FACEBOOK_APP_ID='123'\nFACEBOOK_APP_SECRET='sec'\n", encoding="utf-8")
            state = {"local_config": {}, "github": {"target_repo": "owner/repo"}}
            with patch.object(wizard, "probe_environment", return_value=state):
                instance = wizard.Setup("owner/repo", "full-cloud", state, listing=False)
            instance.project = "demo-proj"
            instance.env = {}
            out = StringIO()
            with (
                patch.object(wizard, "ROOT", root),
                patch.dict(os.environ, {}, clear=True),
                patch.object(wizard, "facebook_enabled", side_effect=[False, True]),
                patch.object(wizard, "confirm", return_value=True),
                patch.object(wizard, "enable_facebook_provider", return_value=True) as enable_fb,
                redirect_stdout(out),
            ):
                self.assertTrue(instance.facebook_sign_in())
            enable_fb.assert_called_once_with("demo-proj", None, "123", "sec")
            self.assertEqual(out.getvalue(), "Facebook sign-in ready.\n")

    def test_facebook_sign_in_prompts_rotate_when_missing_and_falls_back_to_console_url(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = {"local_config": {}, "github": {"target_repo": "owner/repo"}}
            with patch.object(wizard, "probe_environment", return_value=state):
                instance = wizard.Setup("owner/repo", "full-cloud", state, listing=False)
            instance.project = "demo-proj"
            instance.env = {}
            out = StringIO()
            err = StringIO()
            with (
                patch.object(wizard, "ROOT", root),
                patch.dict(os.environ, {}, clear=True),
                patch.object(wizard, "facebook_enabled", return_value=False),
                patch.object(wizard, "confirm", side_effect=[True, False]),
                patch.object(wizard, "run", return_value=0) as mock_run,
                redirect_stdout(out),
                redirect_stderr(err),
            ):
                self.assertFalse(instance.facebook_sign_in())
            mock_run.assert_called_once_with(
                "python3", "scripts/secrets/rotate.py", "--repo", "owner/repo", "--yes",
                "FACEBOOK_APP_ID", "FACEBOOK_APP_SECRET",
            )
            url = "https://console.firebase.google.com/project/demo-proj/authentication/providers"
            self.assertIn(url, out.getvalue())
            self.assertIn(url, err.getvalue())

    def test_release_branches_lists_missing_and_creates_with_single_confirm(self):
        state = {
            "local_config": {},
            "github": {"target_repo": "alice/foodsavr", "branches": ["develop"]},
        }
        listing_out = StringIO()
        with patch.object(wizard, "probe_environment", return_value=state), redirect_stdout(listing_out):
            listing_instance = wizard.Setup("alice/foodsavr", "fork-agents", state, listing=True)
            listing_instance.topology = "full-channels"
            self.assertTrue(listing_instance.release_branches())
        self.assertEqual(listing_out.getvalue(), "Release channels\n")

        out = StringIO()
        updated_state = {
            "local_config": {},
            "github": {"target_repo": "alice/foodsavr", "branches": list(wizard.TOPOLOGY_BRANCHES["full-channels"])},
        }
        with (
            patch.object(wizard, "confirm", return_value=True) as mock_confirm,
            patch.object(wizard, "ensure_branches") as mock_ensure,
            patch.object(wizard, "probe_environment", side_effect=[state, updated_state]),
            redirect_stdout(out),
        ):
            instance = wizard.Setup("alice/foodsavr", "fork-agents", state, listing=False)
            instance.topology = "full-channels"
            self.assertTrue(instance.release_branches())
        mock_confirm.assert_called_once_with("Create missing release channels (daily, weekly, stable)?")
        mock_ensure.assert_called_once_with(
            repo="alice/foodsavr",
            topology="full-channels",
            default_branch="develop",
        )
        self.assertIn("Missing release channels (full-channels) on alice/foodsavr: daily, weekly, stable", out.getvalue())
        self.assertIn("Release channels ready.", out.getvalue())

    def test_primary_environment_prefers_the_test_project(self):
        environments = [{"name": "development", "emulator": True}, {"name": "test"}, {"name": "production"}]
        self.assertEqual(wizard.primary_environment(environments), "test")
        self.assertEqual(wizard.primary_environment([{"name": "production"}]), "production")
        self.assertEqual(wizard.primary_environment(environments, "production"), "production")

    def test_identities_are_recorded_in_the_local_overlay_not_the_manifest(self):
        tracked = (wizard.ROOT / "deploy/instance.yaml").read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as directory, patch.dict(
            os.environ, {"FOODSAVR_INSTANCE_LOCAL": str(Path(directory) / "instance.local.json")},
        ):
            self.assertTrue(wizard.record_identity("test", "example-project", "1:9:web:9", "owner/repo",
                                                   ["develop", "daily", "weekly"]))
            self.assertTrue(wizard.record_identity("production", "example-prod", "1:8:web:8", "owner/repo", ["stable"]))
            self.assertFalse(wizard.record_identity("production", "example-prod", "1:8:web:8", "owner/repo", ["stable"]))
            overlay = wizard.load_instance_local()["deployInstance"]
        self.assertEqual(overlay["identity"], {"githubRepository": "owner/repo"})
        self.assertEqual(overlay["environments"]["test"]["channels"],
                         {"develop": "example-project", "daily": "example-project-daily", "weekly": "example-project-weekly"})
        self.assertEqual(overlay["environments"]["production"]["firebase"]["projectId"], "example-prod")
        self.assertEqual((wizard.ROOT / "deploy/instance.yaml").read_text(encoding="utf-8"), tracked)

    def setup_instance(self):
        state = {"local_config": {}, "github": {"target_repo": "owner/repo", "variables": {}}}
        with patch.object(wizard, "probe_environment", return_value=state):
            instance = wizard.Setup("owner/repo", "full-cloud", state, listing=False)
        instance.project = "demo-proj"
        instance.env = {"ENV": "test"}
        return instance

    def test_production_project_is_skipped_once_provisioned(self):
        instance = self.setup_instance()
        instance.environments = [{"name": "test"}, {"name": "production", "provisioned": True}]
        self.assertTrue(instance.production_project())
        instance.environments = [{"name": "test"}]
        self.assertTrue(instance.production_project())

    def test_unprovisioned_production_is_listed(self):
        instance = self.setup_instance()
        instance.listing = True
        instance.environments = [{"name": "test"}, {"name": "production", "provisioned": False}]
        out = StringIO()
        with redirect_stdout(out):
            self.assertTrue(instance.production_project())
        self.assertEqual(out.getvalue(), "Production Firebase project\n")

    def test_terraform_state_moves_from_production_to_test_once(self):
        instance = self.setup_instance()
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"XDG_STATE_HOME": directory}):
            legacy = wizard.local_state_path("owner/repo", "gcp-demo-proj-production")
            current = wizard.local_state_path("owner/repo", "gcp-demo-proj-test")
            self.assertTrue(instance.terraform_state("test"))
            legacy.parent.mkdir(parents=True)
            legacy.write_text("{}")
            with patch.object(wizard, "confirm", return_value=True), redirect_stdout(StringIO()):
                self.assertTrue(instance.terraform_state("test"))
            self.assertFalse(legacy.exists())
            self.assertEqual(current.read_text(), "{}")
            legacy.write_text("{}")
            with redirect_stderr(StringIO()) as errors:
                self.assertFalse(instance.terraform_state("test"))
            self.assertIn("Both", errors.getvalue())

    def test_infrastructure_checks_each_environment_with_its_suffix(self):
        instance = self.setup_instance()
        instance.environments = [{"name": "test"}, {"name": "production", "provisioned": True}]
        instance.state["github"]["variables"] = {
            f"{name}_TEST": "x" for name in (
                "GCP_WORKLOAD_IDENTITY_PROVIDER", "GCP_DEPLOY_SERVICE_ACCOUNT",
                "GCP_TELEMETRY_SERVICE_ACCOUNT", "RECAPTCHA_ENTERPRISE_SITE_KEY",
            )
        }
        calls, _ = self.run_infrastructure(instance, committed="foodsavr-prod", local="foodsavr-prod")
        self.assertEqual(calls, [
            ("Firebase configuration (test)", "test", "1"),
            ("Firebase configuration", "production", "0"),
        ])

    def run_infrastructure(self, instance, committed, local):
        instance.env["MANIFEST"] = str(wizard.ROOT / "deploy/instance.yaml")
        instance.state["tools"] = {"terraform": True}
        out = StringIO()
        with patch.object(wizard, "terraform_step", return_value=True) as step, \
                patch.object(wizard, "published_project", return_value=committed) as committed_mock, \
                patch.object(wizard, "firebase_identity", return_value=(local, "1:9:web:9")), \
                patch.object(instance, "cloud_authenticated", return_value=True), \
                patch.object(instance, "terraform_state", return_value=True), \
                redirect_stdout(out):
            self.assertTrue(instance.firebase_infrastructure())
        if committed_mock.called:
            self.assertEqual(committed_mock.call_args.args[1], "production")
        return [(c.args[0], c.args[2]["ENV"], c.args[2]["SETUP_GCP_OUTPUTS_READY"]) for c in step.call_args_list], (
            out.getvalue()
        )

    def test_production_is_not_applied_in_the_run_that_created_it(self):
        instance = self.setup_instance()
        instance.environments = [{"name": "test"}, {"name": "production", "provisioned": True}]
        instance.production_created = True
        calls, output = self.run_infrastructure(instance, committed="foodsavr-prod", local="foodsavr-prod")
        self.assertEqual([env for _, env, _ in calls], ["test"])
        self.assertIn("this run created the production project", output)
        self.assertIn("Verify the legal texts and account deletion, then run make setup again", output)

    def test_production_is_applied_only_when_published_to_ci(self):
        for committed in ("", "other-prod"):
            with self.subTest(committed=committed):
                instance = self.setup_instance()
                instance.environments = [{"name": "test"}, {"name": "production", "provisioned": True}]
                calls, output = self.run_infrastructure(instance, committed=committed, local="foodsavr-prod")
                self.assertEqual([env for _, env, _ in calls], ["test"])
                self.assertIn("production project foodsavr-prod is not published in DEPLOY_INSTANCE", output)

    def test_creating_production_prints_the_next_steps(self):
        instance = self.setup_instance()
        instance.environments = [{"name": "test"}, {"name": "production", "provisioned": False}]
        instance.env["MANIFEST"] = "/tmp/instance.yaml"
        out = StringIO()
        with patch.object(wizard.shutil, "which", return_value="/usr/bin/firebase"), \
                patch.object(wizard, "load_instance_local", return_value={}), \
                patch.object(wizard, "save_instance_local"), \
                patch("builtins.input", return_value="foodsavr-prod"), \
                patch.object(wizard, "firebase_project_exists", return_value=True), \
                patch.object(wizard, "firebase_web_app", return_value="1:9:web:9"), \
                patch.object(wizard, "default_site_exists", return_value=True), \
                patch.object(wizard, "record_identity", return_value=True), \
                patch.object(wizard, "manifest_environments", return_value=[]), \
                patch.object(wizard, "firebase_identity", return_value=("foodsavr-prod", "1:9:web:9")), \
                redirect_stdout(out):
            self.assertTrue(instance.production_project())
        self.assertTrue(instance.production_created)
        for step in ("DEPLOY_INSTANCE", "verify the legal texts and account deletion", "Run make setup again"):
            self.assertIn(step, out.getvalue())

    def test_published_project_reads_the_ci_overlay(self):
        overlay = {"environments": {"production": {"firebase": {"projectId": "example-prod"}}}}
        self.assertEqual(wizard.published_project({"DEPLOY_INSTANCE": json.dumps(overlay)}, "production"), "example-prod")
        self.assertEqual(wizard.published_project({"DEPLOY_INSTANCE": json.dumps(overlay)}, "test"), "")
        self.assertEqual(wizard.published_project({}, "production"), "")
        self.assertEqual(wizard.published_project({"DEPLOY_INSTANCE": "not json"}, "production"), "")

    def test_selected_production_is_applied_only_when_published(self):
        instance = self.setup_instance()
        instance.env = {"ENV": "production"}
        instance.environments = [{"name": "test"}, {"name": "production", "provisioned": True}]
        calls, output = self.run_infrastructure(instance, committed="", local="foodsavr-prod")
        self.assertEqual(calls, [])
        self.assertIn("is not published in DEPLOY_INSTANCE", output)
        instance = self.setup_instance()
        instance.env = {"ENV": "production"}
        instance.environments = [{"name": "test"}, {"name": "production", "provisioned": True}]
        calls, _ = self.run_infrastructure(instance, committed="foodsavr-prod", local="foodsavr-prod")
        self.assertEqual([env for _, env, _ in calls], ["production"])

    def test_default_options_keep_the_test_identity_when_production_is_selected(self):
        instance = self.setup_instance()
        instance.env = {"ENV": "production"}
        instance.project, instance.web_app = "foodsavr-prod", "1:9:web:prod"
        instance.environments = [{"name": "test"}, {"name": "production"}]
        seen = []
        with patch.object(wizard, "firebase_identity", return_value=("demo-proj", "1:9:web:test")) as identity, \
                patch.object(wizard, "fingerprint", side_effect=lambda path, project, app: seen.append((project, app)) or True), \
                patch.object(instance, "step", return_value=True):
            self.assertTrue(instance.firebase_app_config())
        self.assertEqual(identity.call_args.args[0]["ENV"], "test")
        self.assertEqual(seen, [("demo-proj", "1:9:web:test")])

    def test_wizard_has_no_menu_paths_or_merge_gate_token(self):
        source = (Path(wizard.__file__)).read_text(encoding="utf-8")
        self.assertNotIn("MERGE_GATE_TOKEN", source)
        self.assertNotIn(" > ", source)
