"""Offline tests for Firebase adoption (adopt.py firebase), safe-plan and firebase_config.py."""

import importlib.util
from io import BytesIO, StringIO
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

HERE = Path(__file__).resolve().parent


def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


adopt = load('adopt')
fc = load('firebase_config')

PROJECT = 'demo-proj'
DB = f'projects/{PROJECT}/databases/(default)'
INDEX = f'{DB}/collectionGroups/products/indexes/CICAgJim14AK'


def not_found(url):
    return HTTPError(url, 404, 'Not Found', {}, BytesIO(b'{}'))


class FakeApi:
    """urlopen stand-in keyed by URL prefix; records every request."""

    def __init__(self, responses):
        self.responses, self.requests = responses, []

    def __call__(self, request, timeout=None):
        self.requests.append(request)
        for prefix, body in self.responses.items():
            if request.full_url.startswith(prefix):
                if isinstance(body, Exception):
                    raise body
                return BytesIO(json.dumps(body).encode())
        raise not_found(request.full_url)


class AdoptFirebaseTests(unittest.TestCase):
    def run_adopt(self, enabled, responses, indexes):
        with tempfile.TemporaryDirectory() as directory:
            index_file = Path(directory) / 'firestore.indexes.json'
            index_file.write_text(json.dumps({'indexes': indexes}))
            api = FakeApi(responses)
            out = StringIO()
            services = [{'config': {'name': name}} for name in enabled]
            with (
                patch.object(adopt, 'command_json', return_value=services),
                patch.object(adopt, 'urlopen', api),
                patch.dict(os.environ, {'GOOGLE_OAUTH_ACCESS_TOKEN': 'tok'}),
                patch.object(sys, 'stdout', out),
            ):
                adopt.firebase_resources(directory, PROJECT, str(index_file))
            return (Path(directory) / 'adopt_firebase.tf').read_text(), out.getvalue().strip(), api

    def test_existing_resources_are_imported_by_their_api_names(self):
        declared = {'collectionGroup': 'products', 'queryScope': 'COLLECTION', 'fields': [
            {'fieldPath': 'userId', 'order': 'ASCENDING'}, {'fieldPath': 'createdAt', 'order': 'DESCENDING'}]}
        live_index = {'name': INDEX, 'queryScope': 'COLLECTION', 'fields': [
            *declared['fields'], {'fieldPath': '__name__', 'order': 'DESCENDING'}]}
        android = '1:1:android:abc'
        text, printed, api = self.run_adopt(
            ['firestore.googleapis.com', 'firebaserules.googleapis.com', 'firebase.googleapis.com',
             'firebaseappcheck.googleapis.com', 'identitytoolkit.googleapis.com'],
            {
                f'https://firestore.googleapis.com/v1/{DB}/collectionGroups': {'indexes': [live_index]},
                f'https://firestore.googleapis.com/v1/{DB}': {'name': DB},
                'https://firebaserules.googleapis.com/': {'name': f'projects/{PROJECT}/releases/cloud.firestore'},
                'https://firebase.googleapis.com/': {'apps': [
                    {'appId': '1:1:android:other', 'packageName': 'com.example'},
                    {'appId': android, 'packageName': 'com.foodsavr.app', 'state': 'ACTIVE'}]},
                'https://identitytoolkit.googleapis.com/': {'defaultSupportedIdpConfigs': [
                    {'name': f'projects/{PROJECT}/defaultSupportedIdpConfigs/facebook.com', 'clientSecret': 'live-secret'}]},
            },
            [declared],
        )
        self.assertEqual(printed, android)
        self.assertIn(f'to = google_firestore_database.default\n  id = "{DB}"', text)
        self.assertIn(f'id = "{INDEX}"', text)
        self.assertIn('google_firestore_index.composite["products/COLLECTION/userId:ASCENDING/createdAt:DESCENDING"]', text)
        self.assertIn('to = google_firebaserules_release.firestore', text)
        self.assertIn(f'id = "projects/{PROJECT}/apps/{android}/playIntegrityConfig"', text)
        # Providers are adopted only while Terraform manages them (credentials present).
        self.assertIn('idp if contains(keys(var.identity_providers), idp)', text)
        self.assertIn('["facebook.com"]', text)
        self.assertNotIn('live-secret', text + printed)
        self.assertTrue(all(r.get_method() == 'GET' for r in api.requests))

    def test_missing_resources_and_disabled_apis_produce_no_imports(self):
        text, printed, api = self.run_adopt(['firestore.googleapis.com', 'firebaserules.googleapis.com'], {}, [])
        self.assertEqual((text, printed), ('', ''))
        self.assertEqual(len(api.requests), 2)
        text, printed, api = self.run_adopt([], {}, [])
        self.assertEqual((text, printed, api.requests), ('', '', []))

    def test_other_api_errors_stop_instead_of_planning_creation(self):
        forbidden = HTTPError('u', 403, 'Forbidden', {}, BytesIO(b'{}'))
        with self.assertRaises(ValueError):
            self.run_adopt(['firestore.googleapis.com'], {'https://firestore.googleapis.com/': forbidden}, [])

    def test_firestore_location_reads_existing_database_location_id(self):
        for enabled, responses, expected in (
            (['firestore.googleapis.com'], {f'https://firestore.googleapis.com/v1/{DB}': {'name': DB, 'locationId': 'eur3'}}, 'eur3'),
            (['firestore.googleapis.com'], {}, ''),
            ([], {}, ''),
        ):
            with self.subTest(expected=expected):
                out = StringIO()
                services = [{'config': {'name': name}} for name in enabled]
                with (
                    patch.object(adopt, 'command_json', return_value=services),
                    patch.object(adopt, 'urlopen', FakeApi(responses)),
                    patch.dict(os.environ, {'GOOGLE_OAUTH_ACCESS_TOKEN': 'tok'}),
                    patch.object(sys, 'stdout', out),
                ):
                    adopt.firestore_location(PROJECT)
                self.assertEqual(out.getvalue().strip(), expected)


class SafePlanTests(unittest.TestCase):
    def safe(self, changes, *, recovery='true', variables=None):
        plan = {
            'variables': {'local_recovery': {'value': True}} if variables is None else variables,
            'resource_changes': changes,
        }
        with patch.object(sys, 'stdin', StringIO(json.dumps(plan))), patch.object(sys, 'stdout', StringIO()) as out:
            adopt.safe_plan(recovery)
        return out.getvalue().strip()

    def test_rules_replacement_is_allowed_but_removals_are_not(self):
        self.assertEqual(self.safe([
            {'address': 'google_firebaserules_ruleset.firestore', 'change': {'actions': ['create', 'delete']}},
            {'address': 'google_firebaserules_release.firestore', 'change': {'actions': ['delete', 'create']}},
        ]), 'true')
        for address in ('google_firebaserules_release.firestore', 'google_firestore_database.default'):
            with self.subTest(address=address), self.assertRaises(ValueError):
                self.safe([{'address': address, 'change': {'actions': ['delete']}}])

    def test_firebase_adoption_imports_do_not_classify_gcs_plan_as_local_recovery(self):
        self.assertEqual(self.safe([
            {'address': 'google_firestore_database.default', 'change': {'actions': ['no-op'], 'importing': {'id': DB}}},
            {'address': 'google_firestore_index.composite["products"]', 'change': {'actions': ['no-op'], 'importing': {'id': INDEX}}},
        ], recovery='false', variables={}), 'false')
        # Deletes and replacements are still rejected on non-recovery saved plans.
        with self.assertRaises(ValueError):
            self.safe([
                {'address': 'google_firestore_database.default', 'change': {'actions': ['delete', 'create'], 'importing': {'id': DB}}},
            ], recovery='false', variables={})


class AuthSettingsTests(unittest.TestCase):
    sites = ['demo-proj-daily']

    def test_changes_only_add_domains_and_keep_runtime_ones(self):
        config = {'signIn': {'email': {'enabled': True}}, 'authorizedDomains': [
            'localhost', 'demo-proj.web.app', 'demo-proj--pr-1-abc.web.app']}
        fields, domains = fc.changes(config, PROJECT, self.sites)
        self.assertEqual(fields, ['signIn.email.passwordRequired', 'signIn.anonymous.enabled'])
        self.assertEqual(domains, ['demo-proj.firebaseapp.com', 'demo-proj-daily.firebaseapp.com', 'demo-proj-daily.web.app'])
        mask, body = fc.patch_body(config, fields, domains)
        self.assertEqual(mask, 'signIn.email.passwordRequired,signIn.anonymous.enabled,authorizedDomains')
        self.assertEqual(body['signIn'], {'email': {'passwordRequired': True}, 'anonymous': {'enabled': True}})
        self.assertEqual(body['authorizedDomains'][:3], config['authorizedDomains'])

    def test_plan_reads_only_and_apply_patches_without_exposing_the_hash_key(self):
        config = {'signIn': {'hashConfig': {'signerKey': 'hash-secret'}}, 'authorizedDomains': ['localhost']}
        for apply, expected in ((False, 2), (True, 0)):
            with self.subTest(apply=apply):
                api = FakeApi({'https://identitytoolkit.googleapis.com/': config})
                out = StringIO()
                with patch.object(sys, 'stdout', out):
                    self.assertEqual(fc.reconcile(fc.Client(PROJECT, 'tok', api), self.sites, apply), expected)
                methods = [r.get_method() for r in api.requests]
                self.assertEqual(methods, ['GET', 'GET', 'PATCH'] if apply else ['GET'])
                self.assertNotIn('hash-secret', out.getvalue())
                if apply:
                    sent = json.loads(api.requests[-1].data)
                    self.assertNotIn('hashConfig', json.dumps(sent))
                    self.assertIn('demo-proj-daily.web.app', sent['authorizedDomains'])

    def test_apply_re_reads_authorized_domains_before_patch_to_keep_concurrent_additions(self):
        reads = [
            {'signIn': {'email': {'enabled': True, 'passwordRequired': True}, 'anonymous': {'enabled': True}},
             'authorizedDomains': ['localhost']},
            {'signIn': {'email': {'enabled': True, 'passwordRequired': True}, 'anonymous': {'enabled': True}},
             'authorizedDomains': ['localhost', 'demo-proj--pr-99.web.app']},
        ]
        requests = []

        def opener(request, timeout=None):
            requests.append(request)
            body = reads.pop(0) if request.get_method() == 'GET' and reads else {}
            return BytesIO(json.dumps(body).encode())

        with patch.object(sys, 'stdout', StringIO()):
            self.assertEqual(fc.reconcile(fc.Client(PROJECT, 'tok', opener), self.sites, True), 0)
        self.assertEqual([r.get_method() for r in requests], ['GET', 'GET', 'PATCH'])
        sent = json.loads(requests[-1].data)
        self.assertIn('demo-proj--pr-99.web.app', sent['authorizedDomains'])
        self.assertIn('demo-proj-daily.web.app', sent['authorizedDomains'])

    def test_in_sync_config_needs_no_change(self):
        config = {'signIn': {'email': {'enabled': True, 'passwordRequired': True}, 'anonymous': {'enabled': True}},
                  'authorizedDomains': fc.desired_domains(PROJECT, self.sites)}
        api = FakeApi({'https://identitytoolkit.googleapis.com/': config})
        with patch.object(sys, 'stdout', StringIO()):
            self.assertEqual(fc.reconcile(fc.Client(PROJECT, 'tok', api), self.sites, True), 0)
        self.assertEqual(len(api.requests), 1)

    def test_check_reports_rules_drift_and_missing_database(self):
        api = FakeApi({
            'https://firebaserules.googleapis.com/v1/projects/demo-proj/releases': {'rulesetName': f'projects/{PROJECT}/rulesets/r1'},
            'https://firebaserules.googleapis.com/v1/projects/demo-proj/rulesets/r1': {'source': {'files': [{'content': 'old'}]}},
            'https://identitytoolkit.googleapis.com/': {'signIn': {}, 'authorizedDomains': []},
        })
        problems = fc.check(fc.Client(PROJECT, 'tok', api), [], 'new\n')
        self.assertIn('Firestore (default) database is missing', problems)
        self.assertIn('released Firestore rules differ from firestore.rules', problems)
        self.assertIn('authorized domain localhost is missing', problems)

    def test_enforced_firestore_requires_an_android_sha256(self):
        api = FakeApi({
            f'https://firestore.googleapis.com/v1/{DB}': {'name': DB},
            'https://firebaserules.googleapis.com/v1/projects/demo-proj/releases': {'rulesetName': f'projects/{PROJECT}/rulesets/r1'},
            'https://firebaserules.googleapis.com/v1/projects/demo-proj/rulesets/r1': {'source': {'files': [{'content': 'r'}]}},
            'https://identitytoolkit.googleapis.com/': {
                'signIn': {'email': {'enabled': True, 'passwordRequired': True}, 'anonymous': {'enabled': True}},
                'authorizedDomains': fc.desired_domains(PROJECT, [])},
            'https://firebaseappcheck.googleapis.com/': {'enforcementMode': 'ENFORCED'},
            'https://firebase.googleapis.com/v1beta1/projects/demo-proj/androidApps/a1/sha': {'certificates': [{'certType': 'SHA_1'}]},
            'https://firebase.googleapis.com/v1beta1/projects/demo-proj/androidApps': {'apps': [{'appId': 'a1', 'packageName': 'com.foodsavr.app'}]},
        })
        problems = fc.check(fc.Client(PROJECT, 'tok', api), [], 'r')
        self.assertEqual(len(problems), 1)
        self.assertIn('no SHA-256 fingerprint', problems[0])


class CredentialTests(unittest.TestCase):
    def test_only_complete_credentials_are_managed_and_env_wins_over_dotenv(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.env').write_text("FACEBOOK_APP_ID='123'\nFACEBOOK_APP_SECRET='fb-secret'\nGOOGLE_WEB_CLIENT_SECRET=g-secret\n")
            self.assertEqual(fc.credentials(root, {}), {'facebook.com': ('123', 'fb-secret')})
            (root / 'android/app').mkdir(parents=True)
            (root / 'android/app/google-services.json').write_text(json.dumps(
                {'client': [{'oauth_client': [{'client_id': 'android', 'client_type': 1},
                                              {'client_id': 'web-id', 'client_type': 3}]}]}))
            found = fc.credentials(root, {'FACEBOOK_APP_SECRET': 'env-secret'})
            self.assertEqual(found, {'google.com': ('web-id', 'g-secret'), 'facebook.com': ('123', 'env-secret')})

    def test_providers_output_has_no_secrets(self):
        out = StringIO()
        with (
            patch.object(fc, 'credentials', return_value={'facebook.com': ('123', 'fb-secret')}),
            patch.object(sys, 'stdout', out),
        ):
            self.assertEqual(fc.main(['providers']), 0)
        self.assertEqual(json.loads(out.getvalue()), {'facebook.com': {'client_id': '123'}})
        self.assertNotIn('fb-secret', out.getvalue())


if __name__ == '__main__':
    unittest.main()
