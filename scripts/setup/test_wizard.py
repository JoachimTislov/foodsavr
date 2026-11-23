from argparse import Namespace
from contextlib import redirect_stdout
from io import StringIO
from unittest import TestCase
from unittest.mock import Mock, patch

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

    def test_owner_names_omit_username_and_truncation_preserves_role(self):
        self.assertEqual(app_name("JoachimTislov/foodsavr", "release-gate"), "foodsavr-release-gate")
        repo = "long-owner-for-fork/long-name-for-a-fork-of-foodsavr"
        name = app_name(repo, "release-gate", owner_suffix=True)
        self.assertLessEqual(len(name), 34)
        self.assertTrue(name.endswith("-release-gate-long-own"))
