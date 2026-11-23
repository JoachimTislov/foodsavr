import base64
import json
import os
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
sys.path.insert(0, str(ROOT / "scripts/secrets"))
import rotate

PROJECT = "fixture-project"
WEB_ID = "1:1234:web:valid"
ANDROID_ID = "1:1234:android:valid"
GOOD_DART = b"class DefaultFirebaseOptions { static const web = FirebaseOptions(); }\n"


class FirebaseOptionsTest(unittest.TestCase):
    def test_rotation_rejects_empty_non_utf8_and_file_without_constructor(self):
        registry = rotate.load_registry()
        secret = registry["FIREBASE_OPTIONS_B64"]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / secret.sync_file
            path.parent.mkdir()
            for content in (b"", b"\xff\xfe", b"class DefaultFirebaseOptions {}"):
                path.write_bytes(content)
                with self.subTest(content=content), self.assertRaises(ValueError):
                    rotate.generate(secret, root=root)

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
            self.assertTrue(firebase_options.fingerprint(path, PROJECT, WEB_ID))
            self.assertIsNone(firebase_options.fingerprint(path, "other-project", WEB_ID))
        read.assert_called_with(PROJECT, "apps:sdkconfig", "ANDROID", ANDROID_ID)

    @unittest.skipUnless(shutil.which("dart"), "Flutter SDK unavailable")
    def test_ci_rejects_corrupt_or_malformed_dart_without_replacing_existing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "lib/firebase_options.dart"
            output.parent.mkdir()
            output.write_bytes(GOOD_DART)
            for corrupt in (b"\xff\xfe", b"class DefaultFirebaseOptions { static const web = FirebaseOptions( }"):
                env = {**os.environ, "FIREBASE_OPTIONS_B64": base64.b64encode(corrupt).decode()}
                tolerant = subprocess.run(
                    ["bash", str(ROOT / "scripts/ci/write_firebase_options.sh")],
                    cwd=directory, env=env, capture_output=True, text=True,
                )
                self.assertEqual(tolerant.returncode, 0, tolerant.stderr)
                self.assertEqual(output.read_bytes(), GOOD_DART)

                strict = subprocess.run(
                    ["bash", str(ROOT / "scripts/ci/write_firebase_options.sh"), "--require-real"],
                    cwd=directory, env=env, capture_output=True, text=True,
                )
                self.assertEqual(strict.returncode, 1)
                self.assertEqual(len(strict.stderr.splitlines()), 1)
                self.assertIn("valid Firebase Dart options", strict.stderr)
                self.assertEqual(output.read_bytes(), GOOD_DART)
