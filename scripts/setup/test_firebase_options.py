import json
from pathlib import Path
import shutil
import subprocess
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
GOOD_DART = b"class DefaultFirebaseOptions { static const web = FirebaseOptions(); }\n"


class FirebaseOptionsTest(unittest.TestCase):
    @unittest.skipUnless(shutil.which("dart"), "Flutter SDK unavailable")
    def test_fingerprint_requires_both_ids_in_uncommented_web_options(self):
        web = {
            "apiKey": "https://example.test/key", "appId": WEB_ID,
            "messagingSenderId": "1234", "projectId": "old-web-project",
        }
        android = {**web, "appId": ANDROID_ID, "projectId": PROJECT}
        source = firebase_options.render({"web": web, "android": android}).decode()
        comment = f"/* ignored /* nested */ projectId: '{PROJECT}', */"
        source = source.replace("projectId: 'old-web-project',", f"{comment} projectId: 'old-web-project',")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "firebase_options.dart"
            path.write_text(source)
            self.assertIsNone(firebase_options.fingerprint(path, PROJECT, WEB_ID))
            self.assertIsNone(firebase_options.fingerprint(path, PROJECT, ANDROID_ID))
            self.assertIsNotNone(firebase_options.fingerprint(path, "old-web-project", WEB_ID))

    @unittest.skipUnless(shutil.which("dart"), "Flutter SDK unavailable")
    def test_recovery_matches_exact_android_package_and_manifest_web_app(self):
        web = {
            "apiKey": "web-test-key", "appId": WEB_ID, "messagingSenderId": "1234", "projectId": PROJECT,
        }
        android = {
            "project_info": {"project_number": "1234", "project_id": PROJECT},
            "client": [
                {
                    "client_info": {
                        "mobilesdk_app_id": ANDROID_ID,
                        "android_client_info": {"package_name": "com.foodsavr.app"},
                    },
                    "api_key": [{"current_key": "android-test-key"}],
                },
            ],
        }
        read = Mock(side_effect=[
            [{"appId": "wrong-web"}, {"appId": WEB_ID}],
            [{"appId": "wrong-android", "packageName": "com.foodsavr.app.dev"},
             {"appId": ANDROID_ID, "packageName": "com.foodsavr.app"}],
            {"sdkConfig": web},
            {"fileContents": json.dumps(android)},
        ])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "firebase_options.dart"
            path.write_bytes(b"\xff\xfe")
            firebase_options.regenerate(path, PROJECT, WEB_ID, read=read)
            source = path.read_text()
            self.assertIn(WEB_ID, source)
            self.assertIn(ANDROID_ID, source)
            self.assertIn("TargetPlatform.android", source)
            self.assertIn(f"apiKey: 'web-test-key'", source)
            self.assertNotIn('"', source)
            fmt = subprocess.run(
                ["dart", "format", "--output=none", "--set-exit-if-changed", str(path)],
                capture_output=True, text=True,
            )
            self.assertEqual(fmt.returncode, 0, fmt.stdout + fmt.stderr)
            self.assertTrue(firebase_options.fingerprint(path, PROJECT, WEB_ID))
            self.assertIsNone(firebase_options.fingerprint(path, "other-project", WEB_ID))
        read.assert_called_with(PROJECT, "apps:sdkconfig", "ANDROID", ANDROID_ID)

    @unittest.skipUnless(shutil.which("dart"), "Flutter SDK unavailable")
    def test_render_escapes_special_characters_for_single_quoted_dart(self):
        rendered = firebase_options.render({
            "web": {
                "apiKey": "a'b$c\\d",
                "appId": WEB_ID,
                "messagingSenderId": "1234",
                "projectId": PROJECT,
            }
        })
        source = rendered.decode("utf-8")
        self.assertIn(r"apiKey: 'a\'b\$c\\d'", source)
        self.assertEqual(firebase_options.validate(rendered, syntax=True), source)
