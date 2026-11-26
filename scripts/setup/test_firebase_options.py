import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import firebase_options

PROJECT = "fixture-project"
WEB_ID = "1:1234:web:valid"
ANDROID_ID = "1:1234:android:valid"
WEB = {"apiKey": "web-test-key", "appId": WEB_ID, "messagingSenderId": "1234", "projectId": PROJECT,
       "authDomain": f"{PROJECT}.firebaseapp.com"}


class FirebaseOptionsTest(unittest.TestCase):
    def test_render_maps_sdk_config_to_defines_and_validates(self):
        rendered = firebase_options.render({"web": WEB, "android": {"apiKey": "android-key", "appId": ANDROID_ID}})
        defines = firebase_options.validate(rendered)
        self.assertEqual(defines["FIREBASE_PROJECT_ID"], PROJECT)
        self.assertEqual(defines["FIREBASE_WEB_APP_ID"], WEB_ID)
        self.assertEqual(defines["FIREBASE_ANDROID_APP_ID"], ANDROID_ID)
        self.assertEqual(defines["FIREBASE_AUTH_DOMAIN"], f"{PROJECT}.firebaseapp.com")
        with self.assertRaises(ValueError):
            firebase_options.render({"web": {"projectId": PROJECT}})
        with self.assertRaises(ValueError):
            firebase_options.validate(b'{"FIREBASE_PROJECT_ID": "x"}')

    def test_fingerprint_requires_both_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "firebase.json"
            path.write_bytes(firebase_options.render({"web": WEB}))
            self.assertTrue(firebase_options.fingerprint(path, PROJECT, WEB_ID))
            self.assertIsNone(firebase_options.fingerprint(path, "other-project", WEB_ID))
            self.assertIsNone(firebase_options.fingerprint(path, PROJECT, ANDROID_ID))
            self.assertIsNone(firebase_options.fingerprint(Path(directory) / "missing.json", PROJECT, WEB_ID))

    def test_recovery_matches_exact_android_package_and_manifest_web_app(self):
        android = {
            "project_info": {"project_number": "1234", "project_id": PROJECT},
            "client": [{
                "client_info": {"mobilesdk_app_id": ANDROID_ID, "android_client_info": {"package_name": "com.foodsavr.app"}},
                "api_key": [{"current_key": "android-test-key"}],
            }],
        }
        read = Mock(side_effect=[
            [{"appId": "wrong-web"}, {"appId": WEB_ID}],
            [{"appId": "wrong-android", "packageName": "com.foodsavr.app.dev"},
             {"appId": ANDROID_ID, "packageName": "com.foodsavr.app"}],
            {"sdkConfig": WEB},
            {"fileContents": json.dumps(android)},
        ])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".agents/state/firebase.defines.json"
            firebase_options.regenerate(path, PROJECT, WEB_ID, read=read)
            defines = json.loads(path.read_text())
            self.assertEqual(defines["FIREBASE_ANDROID_API_KEY"], "android-test-key")
            self.assertEqual(defines["FIREBASE_WEB_API_KEY"], "web-test-key")
            self.assertTrue(firebase_options.fingerprint(path, PROJECT, WEB_ID))
        read.assert_called_with(PROJECT, "apps:sdkconfig", "ANDROID", ANDROID_ID)

    def test_tracked_dart_options_hold_no_project_values(self):
        source = (ROOT / "lib/firebase_options.dart").read_text()
        self.assertRegex(source, r"String\.fromEnvironment\(\s*'FIREBASE_PROJECT_ID'")
        self.assertNotRegex(source, r"projectId:\s*'")


if __name__ == "__main__":
    unittest.main()
