"""Offline regression tests for free-instance bootstrap, split Terraform roots, and state safety."""

import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from urllib.error import HTTPError

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
spec = importlib.util.spec_from_file_location('bootstrap_support', HERE / 'bootstrap_support.py')
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)


class DiscoveryTests(unittest.TestCase):
    def test_discovers_management_key_id_without_exposing_key_value(self):
        def opener(request, timeout):
            self.assertEqual(timeout, 30)
            self.assertEqual(request.headers['Authorization'], 'Bearer test-token')
            self.assertIn('/projects/demo-proj/webApps/1%3A123%3Aweb%3Aabc', request.full_url)
            return io.BytesIO(b'{"apiKeyId":"key-id","apiKey":"not-returned"}')
        self.assertEqual(support.discover_api_key('demo-proj', '1:123:web:abc', 'test-token', opener), 'key-id')

    def test_rejects_missing_or_invalid_key_id(self):
        for payload in [{}, {'apiKeyId': 'bad"\nvalue'}, [], {'apiKeyId': 123}]:
            with self.subTest(payload=payload), self.assertRaisesRegex(ValueError, 'webApiKeyId'):
                support.discover_api_key('p', 'a', 't', lambda *a, **kw: io.BytesIO(json.dumps(payload).encode()))

    def test_http_error_has_actionable_message_without_response_body(self):
        def opener(*args, **kwargs):
            raise HTTPError('url', 403, 'denied', {}, io.BytesIO(b'sensitive'))
        with self.assertRaisesRegex(ValueError, 'Check Firebase read access') as error:
            support.discover_api_key('p', 'a', 't', opener)
        self.assertNotIn('sensitive', str(error.exception))


class StatePathTests(unittest.TestCase):
    def test_uses_xdg_state_home_when_set(self):
        path = support.local_state_path('alice/foodsavr', 'github', xdg_state_home='/tmp/xdg-state')
        self.assertEqual(path, Path('/tmp/xdg-state/foodsavr/terraform/alice/foodsavr/github/terraform.tfstate'))

    def test_defaults_to_home_dot_local_state(self):
        path = support.local_state_path('alice/foodsavr', 'gcp-demo-production', xdg_state_home='', home='/tmp/home')
        self.assertEqual(
            path,
            Path('/tmp/home/.local/state/foodsavr/terraform/alice/foodsavr/gcp-demo-production/terraform.tfstate'),
        )

    def test_rejects_path_traversal_and_bad_slugs(self):
        for slug, stack in [
            ('no-slash', 'github'),
            ('../evil/repo', 'github'),
            ('alice/..', 'github'),
            ('alice/repo', '../escape'),
            ('alice/repo', 'a/b'),
        ]:
            with self.subTest(slug=slug, stack=stack), self.assertRaises(ValueError):
                support.local_state_path(slug, stack, xdg_state_home='/tmp/xdg')


FAKE_TOOL = '''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['FAKE_LOG'], 'a') as out:
    out.write(json.dumps([name, args]) + '\\n')
if name == 'dart':
    if args[0] == 'pub': sys.exit(0)
    if args[2] == 'env':
        if args[args.index('--format') + 1] == 'dotenv':
            for key, value in json.loads(os.environ['FAKE_CONFIG']).items(): print(f"{key}='{value}'")
        else:
            print('project_id = "demo-proj"\\nweb_api_key_id = "key-id"')
elif name == 'gcloud':
    if 'print-access-token' in args: print('test-token')
    elif args[:2] == ['billing', 'projects']:
        print(os.environ.get('FAKE_BILLING_ENABLED', ''))
    elif args[:2] == ['projects', 'describe']:
        print('{"projectNumber": "123"}')
    elif args[:2] == ['services', 'list']:
        print('[{"config":{"name":"iam.googleapis.com"}}]')
    elif 'list' in args and 'workload-identity-pools' in args:
        name = 'projects/123/locations/global/workloadIdentityPools/github'
        if 'providers' in args:
            name += '/providers/github-oidc'
        print(json.dumps([{'name': name}]))
    elif 'service-accounts' in args and 'list' in args:
        email = 'github-hosting-deploy@demo-proj.iam.gserviceaccount.com'
        print(json.dumps([{'name': f'projects/demo-proj/serviceAccounts/{email}', 'email': email}]))
    elif 'get-iam-policy' in args:
        print('{"bindings":[]}')
    elif 'describe' in args:
        status = os.environ['FAKE_BUCKET']
        if status == 'exists': print('{}')
        else:
            print('ERROR: ' + status, file=sys.stderr)
            sys.exit(1)
    else:
        print('Unexpected cloud mutation', file=sys.stderr)
        sys.exit(9)
elif name == 'terraform':
    directory = pathlib.Path(args[0].split('=', 1)[1])
    if args[1:3] == ['show', '-json']:
        print(pathlib.Path(args[3]).read_text())
    with open(os.environ['FAKE_CONFIG_LOG'], 'a') as out:
        out.write((directory / 'main.tf').read_text())
        if (directory / 'adopt.tf').is_file():
            out.write((directory / 'adopt.tf').read_text())
        if args[1] == 'plan' and any(a.startswith('-var-file=') for a in args):
            var_file = next(a.split('=', 1)[1] for a in args if a.startswith('-var-file='))
            out.write(pathlib.Path(var_file).read_text())
elif name == 'gh':
    if args[:2] == ['auth', 'token']:
        print('fake-gh-token')
    elif args[:1] == ['api']:
        endpoint = args[-1]
        if '/labels?' in endpoint:
            print(json.dumps([[{'name': 'TYPE/BUG'}, {'name': 'user-custom'}]]))
            sys.exit(0)
        if '/actions/variables?' in endpoint:
            print('[{"variables":[]}]')
            sys.exit(0)
        if '/environments?' in endpoint:
            print('[{"environments":[]}]')
            sys.exit(0)
        if '/rulesets?' in endpoint:
            print('[[]]')
            sys.exit(0)
        endpoint = args[1]
        if endpoint.endswith('/rulesets'):
            sys.exit(0 if os.environ.get('FAKE_RULESETS_OK', 'true') == 'true' else 1)
        print(os.environ.get('FAKE_REPO_PRIVATE', 'false'))
    else:
        sys.exit(1)
'''


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.xdg_state = self.root / 'xdg-state'
        for directory in [
            'scripts/infra',
            'scripts/setup',
            'scripts/github',
            'infra/terraform/gcp',
            'infra/terraform/github',
            '.agents/github',
            'packages/foodsavr_deploy',
            'deploy',
            'bin',
        ]:
            (self.root / directory).mkdir(parents=True)
        for name in ['apply.sh', 'apply-github.sh', 'bootstrap_support.py', 'adopt.py']:
            shutil.copy2(HERE / name, self.root / 'scripts/infra' / name)
        for name in ('scripts/setup/setupctl.py', 'scripts/github/promote_release.py', 'scripts/github/checks.py'):
            shutil.copy2(REPO / name, self.root / name)
        for stack in ('gcp', 'github'):
            for tf_file in (REPO / 'infra/terraform' / stack).glob('*.tf'):
                shutil.copy2(tf_file, self.root / 'infra/terraform' / stack / tf_file.name)
        shutil.copy2(REPO / '.agents/github/labels.json', self.root / '.agents/github/labels.json')
        (self.root / 'deploy/instance.yaml').touch()
        tool = self.root / 'bin/tool'
        tool.write_text(FAKE_TOOL)
        tool.chmod(0o755)
        for name in ['dart', 'gcloud', 'terraform', 'gh']:
            (self.root / 'bin' / name).symlink_to(tool)
        config = {
            'EMULATOR': 'false', 'INFRA_OWNER': 'production',
            'GITHUB_REPOSITORY': 'alice/foodsavr', 'GH_ENVIRONMENT': 'production',
            'PROJECT_ID': 'demo-proj', 'WEB_APP_ID': 'app-id',
            'WEB_API_KEY_ID': 'key-id', 'REGION': 'europe-north1',
            'TF_STATE_BUCKET': 'demo-proj-tfstate', 'TF_STATE_PREFIX': 'firebase',
            'DEPLOYMENT_LEVEL': 'firebase-spark', 'VAR_SUFFIX': '',
        }
        home = self.root / 'home'
        home.mkdir()
        self.env = {
            'PATH': str(self.root / 'bin') + os.pathsep + os.environ.get('PATH', '/usr/bin:/bin'),
            'HOME': str(home),
            'XDG_STATE_HOME': str(self.xdg_state),
            'TMPDIR': str(self.root),
            'FAKE_LOG': str(self.root / 'calls.jsonl'),
            'FAKE_CONFIG_LOG': str(self.root / 'config.log'),
            'FAKE_CONFIG': json.dumps(config),
            'FAKE_BUCKET': '404 NOT_FOUND',
            'ENV': 'production',
            'MANIFEST': str(self.root / 'deploy/instance.yaml'),
        }

    def expected_gcp_state(self):
        return (
            self.xdg_state
            / 'foodsavr/terraform/alice/foodsavr/gcp-demo-proj-production/terraform.tfstate'
        )

    def run_plan(self, *, action='plan', **env):
        return subprocess.run(
            ['bash', str(self.root / 'scripts/infra/apply.sh'), action],
            cwd=self.root,
            env={**self.env, **env},
            text=True,
            capture_output=True,
        )

    def test_new_spark_uses_worktree_safe_xdg_local_state_without_cloud_mutation(self):
        result = self.run_plan()
        self.assertEqual(result.returncode, 0, result.stderr)
        config = (self.root / 'config.log').read_text()
        self.assertIn('backend "local"', config)
        self.assertIn(str(self.expected_gcp_state()), config)
        self.assertIn('backend "gcs"', (self.root / 'infra/terraform/gcp/main.tf').read_text())
        calls = (self.root / 'calls.jsonl').read_text()
        self.assertNotIn('"create"', calls)
        self.assertNotIn('"update"', calls)

    def test_legacy_worktree_state_blocks_silently_starting_empty_xdg_state(self):
        legacy = self.root / '.deployment-state/demo-proj/production/terraform.tfstate'
        legacy.parent.mkdir(parents=True)
        legacy.write_text('{}')
        result = self.run_plan()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Legacy local Terraform state found', result.stderr)
        self.assertIn(str(self.expected_gcp_state()), result.stderr)
        self.assertFalse((self.root / 'config.log').exists())

    def test_existing_bucket_preserves_remote_state(self):
        result = self.run_plan(FAKE_BUCKET='exists')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('backend "gcs"', (self.root / 'config.log').read_text())
        self.assertIn('-backend-config=prefix=firebase', (self.root / 'calls.jsonl').read_text())

    def test_permission_and_network_errors_never_fall_back_to_empty_state(self):
        for status in ['403 PERMISSION_DENIED', 'network unavailable']:
            result = self.run_plan(FAKE_BUCKET=status)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('refusing to select a different backend', result.stderr)
            self.assertFalse((self.root / 'config.log').exists())

    def test_billing_403_adopts_existing_cloud_resources_in_local_plan(self):
        result = self.run_plan(FAKE_BUCKET='403 PERMISSION_DENIED', FAKE_BILLING_ENABLED='False')
        self.assertEqual(result.returncode, 0, result.stderr)
        config = (self.root / 'config.log').read_text()
        self.assertIn('backend "local"', config)
        self.assertIn('to = google_iam_workload_identity_pool.github', config)
        self.assertIn('to = google_iam_workload_identity_pool_provider.github', config)
        self.assertIn('to = google_service_account.deploy_live', config)
        self.assertIn('deploy_service_account_id = "github-hosting-deploy"', config)
        self.assertIn('local_recovery = true', config)
        self.assertFalse(self.expected_gcp_state().exists())
        calls = (self.root / 'calls.jsonl').read_text()
        self.assertNotIn('"apply"', calls)
        self.assertNotIn('"import"', calls)

    def test_saved_recovery_plan_is_guarded_after_bucket_probe_changes(self):
        plan = self.root / 'recovery.tfplan'
        marker = self.expected_gcp_state().parent / 'adopt-local'
        for variables in (
            {'local_recovery': {'value': True}},
            {'deploy_service_account_id': {'value': 'github-hosting-deploy'}},
        ):
            with self.subTest(variables=variables):
                change = {'address': 'google_service_account.deploy_live', 'change': {'actions': ['delete']}}
                plan.write_text(json.dumps({'variables': variables, 'resource_changes': [change]}))
                result = self.run_plan(action='apply', PLAN_FILE=str(plan))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Plan would remove or replace', result.stderr)
                self.assertFalse(marker.exists())
                calls = [json.loads(line) for line in (self.root / 'calls.jsonl').read_text().splitlines()]
                self.assertFalse(any(name == 'terraform' and args[1] == 'apply' for name, args in calls))

                change['change']['actions'] = ['no-op']
                plan.write_text(json.dumps({'variables': variables, 'resource_changes': [change]}))
                result = self.run_plan(action='apply', PLAN_FILE=str(plan))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(marker.exists())
                self.assertEqual(self.run_plan().returncode, 0)
                self.assertIn('deploy_service_account_id = "github-hosting-deploy"', (self.root / 'config.log').read_text())
                marker.unlink()
                (self.root / 'calls.jsonl').unlink()

    def test_billing_403_closed_message_falls_back_even_without_billing_describe(self):
        result = self.run_plan(
            FAKE_BUCKET='403 PERMISSION_DENIED: The billing account for the owning project is closed',
            FAKE_BILLING_ENABLED='',
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('backend "local"', (self.root / 'config.log').read_text())

    def test_mismatched_github_repository_rejects_wrong_manifest(self):
        result = self.run_plan(GITHUB_REPOSITORY='JoachimTislov/foodsavr')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Choose a deployment manifest for JoachimTislov/foodsavr', result.stderr)

    def test_local_override_refuses_existing_remote(self):
        result = self.run_plan(TF_STATE_BACKEND='local', FAKE_BUCKET='exists')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('remote state bucket exists', result.stderr)

    def test_remote_override_refuses_existing_local_state(self):
        state = self.expected_gcp_state()
        state.parent.mkdir(parents=True)
        state.write_text('{}')
        result = self.run_plan(TF_STATE_BACKEND='gcs')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Migrate it explicitly', result.stderr)

    def test_auto_refuses_ambiguous_local_and_remote_state(self):
        state = self.expected_gcp_state()
        state.parent.mkdir(parents=True)
        state.write_text('{}')
        result = self.run_plan(FAKE_BUCKET='exists')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Both local state and a GCS bucket exist', result.stderr)

    def test_apply_github_plan_uses_xdg_state_and_auto_disables_rulesets_on_private_free(self):
        result = subprocess.run(
            ['bash', str(self.root / 'scripts/infra/apply-github.sh'), 'plan'],
            cwd=self.root,
            env={
                **self.env,
                'GITHUB_REPOSITORY': 'alice/foodsavr',
                'RELEASE_TOPOLOGY': 'single',
                'FAKE_REPO_PRIVATE': 'true',
                'FAKE_RULESETS_OK': 'false',
            },
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        expected_state = self.xdg_state / 'foodsavr/terraform/alice/foodsavr/github/terraform.tfstate'
        config = (self.root / 'config.log').read_text()
        self.assertIn(str(expected_state), config)
        calls = (self.root / 'calls.jsonl').read_text()
        self.assertIn('github_issue_label.managed[each.key]', config)
        self.assertIn('TYPE/BUG', config)
        self.assertIn('contains(keys(local.existing_labels), lower(name))', config)
        self.assertIn('-var=enable_rulesets=false', calls)
        self.assertIn('-var=release_topology=single', calls)

    def test_apply_github_plan_leaves_channel_derivation_to_terraform_with_tfvars(self):
        tfvars = self.root / 'github.tfvars'
        tfvars.write_text('release_topology = "two-stage"\n')
        result = subprocess.run(
            ['bash', str(self.root / 'scripts/infra/apply-github.sh'), 'plan'],
            cwd=self.root,
            env={**self.env, 'GITHUB_REPOSITORY': 'alice/foodsavr', 'RELEASE_TOPOLOGY': 'single',
                 'DEFAULT_BRANCH': 'main', 'TFVARS_FILE': str(tfvars)},
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.root / 'calls.jsonl').read_text()
        self.assertNotIn('-var=channel_branches=', calls)
        self.assertIn('-var=default_branch=main', calls)
        self.assertLess(calls.index('-var=release_topology=single'), calls.index(f'-var-file={tfvars}'))
        self.assertIn('? ["develop", "stable"]', (self.root / 'config.log').read_text())


class TerraformRootStructureTests(unittest.TestCase):
    def test_github_root_enforces_adr_0008_invariants(self):
        github_dir = REPO / 'infra/terraform/github'
        main_tf = (github_dir / 'main.tf').read_text()
        rulesets_tf = (github_dir / 'rulesets.tf').read_text()
        variables_tf = (github_dir / 'variables.tf').read_text()

        # Never manage github_repository or github_branch resources.
        self.assertNotIn('resource "github_repository"', main_tf)
        self.assertNotIn('resource "github_branch"', main_tf)
        self.assertIn('data "github_repository" "this"', main_tf)

        # Split rulesets: zero bypass on integrity, release_gate_app_id only on pr_gate.
        integrity_block = rulesets_tf.split('resource "github_repository_ruleset" "release_channels_pr_gate"')[0]
        self.assertIn('release_channels_integrity', integrity_block)
        self.assertNotIn('bypass_actors', integrity_block)
        self.assertNotIn('agent_app_id', rulesets_tf)

        # Kill switches and secrets blocked from actions_variables.
        for forbidden in (
            'FIREBASE_HOSTING_ENABLED',
            'AUTO_HEAL_ENABLED',
            'AUTO_HEAL_MERGE',
            'TELEMETRY_POLL_ENABLED',
            'MONITOR_TARGET_URL',
            'FIRESTORE_RULES_B64',
            'FIREBASE_OPTIONS_B64',
        ):
            self.assertIn(forbidden, variables_tf)

    def test_gcp_root_splits_deploy_and_telemetry_service_accounts(self):
        gcp_main = (REPO / 'infra/terraform/gcp/main.tf').read_text()
        self.assertIn('account_id   = var.deploy_service_account_id', gcp_main)
        self.assertIn('default     = "github-deploy-live"', (REPO / 'infra/terraform/gcp/variables.tf').read_text())
        self.assertIn('account_id   = "github-telemetry-ro"', gcp_main)
        self.assertIn('attribute.repo_ref_env', gcp_main)
        self.assertIn('attribute.repo_ref', gcp_main)
        # Ensure deploy_live does not receive telemetry-only roles and telemetry_ro has no write admin roles.
        deploy_section, telemetry_section = gcp_main.split('resource "google_service_account" "telemetry_ro"')
        self.assertNotIn('roles/datastore.viewer', deploy_section)
        self.assertNotIn('roles/firebasehosting.admin', telemetry_section)
        self.assertNotIn('roles/firebaseauth.admin', telemetry_section)


if __name__ == '__main__':
    unittest.main()
