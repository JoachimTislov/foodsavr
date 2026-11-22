"""Offline regression tests for free-instance bootstrap and state safety."""

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
    with open(os.environ['FAKE_CONFIG_LOG'], 'a') as out:
        out.write((directory / 'main.tf').read_text())
elif name == 'gh': sys.exit(1)
'''


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ['scripts/infra', 'infra/terraform', 'packages/foodsavr_deploy', 'deploy', 'bin']:
            (self.root / directory).mkdir(parents=True)
        for name in ['apply.sh', 'bootstrap_support.py']:
            shutil.copy2(HERE / name, self.root / 'scripts/infra' / name)
        for name in ['main.tf', 'variables.tf']:
            shutil.copy2(REPO / 'infra/terraform' / name, self.root / 'infra/terraform' / name)
        (self.root / 'deploy/instance.yaml').touch()
        tool = self.root / 'bin/tool'
        tool.write_text(FAKE_TOOL)
        tool.chmod(0o755)
        for name in ['dart', 'gcloud', 'terraform', 'gh']:
            (self.root / 'bin' / name).symlink_to(tool)
        config = {
            'EMULATOR': 'false', 'INFRA_OWNER': 'production',
            'PROJECT_ID': 'demo-proj', 'WEB_APP_ID': 'app-id',
            'WEB_API_KEY_ID': 'key-id', 'REGION': 'europe-north1',
            'TF_STATE_BUCKET': 'demo-proj-tfstate', 'TF_STATE_PREFIX': 'firebase',
            'DEPLOYMENT_LEVEL': 'firebase-spark', 'VAR_SUFFIX': '',
        }
        self.env = {**os.environ, 'PATH': str(self.root / 'bin') + os.pathsep + os.environ['PATH'],
                    'FAKE_LOG': str(self.root / 'calls.jsonl'), 'FAKE_CONFIG_LOG': str(self.root / 'config.log'),
                    'FAKE_CONFIG': json.dumps(config), 'FAKE_BUCKET': '404 NOT_FOUND', 'ENV': 'production'}
        self.env.pop('MANIFEST', None)
        self.env.pop('TF_STATE_BACKEND', None)

    def run_plan(self, **env):
        return subprocess.run(['bash', str(self.root / 'scripts/infra/apply.sh'), 'plan'],
                              cwd=self.root, env={**self.env, **env}, text=True, capture_output=True)

    def test_new_spark_uses_local_state_without_cloud_mutation(self):
        result = self.run_plan()
        self.assertEqual(result.returncode, 0, result.stderr)
        config = (self.root / 'config.log').read_text()
        self.assertIn('backend "local"', config)
        self.assertIn(str(self.root / '.deployment-state/demo-proj/production/terraform.tfstate'), config)
        self.assertIn('backend "gcs"', (self.root / 'infra/terraform/main.tf').read_text())
        calls = (self.root / 'calls.jsonl').read_text()
        self.assertNotIn('"create"', calls)
        self.assertNotIn('"update"', calls)

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

    def test_local_override_refuses_existing_remote(self):
        result = self.run_plan(TF_STATE_BACKEND='local', FAKE_BUCKET='exists')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('remote state bucket exists', result.stderr)

    def test_remote_override_refuses_existing_local_state(self):
        state = self.root / '.deployment-state/demo-proj/production/terraform.tfstate'
        state.parent.mkdir(parents=True)
        state.write_text('{}')
        result = self.run_plan(TF_STATE_BACKEND='gcs')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Migrate it explicitly', result.stderr)

    def test_auto_refuses_ambiguous_local_and_remote_state(self):
        state = self.root / '.deployment-state/demo-proj/production/terraform.tfstate'
        state.parent.mkdir(parents=True)
        state.write_text('{}')
        result = self.run_plan(FAKE_BUCKET='exists')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Both local state and a GCS bucket exist', result.stderr)


if __name__ == '__main__':
    unittest.main()
