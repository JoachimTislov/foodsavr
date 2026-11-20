import base64
from contextlib import contextmanager
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from prepare_android import prepare
from upload_drive import upload


@contextmanager
def workspace():
    previous = Path.cwd()
    with tempfile.TemporaryDirectory() as directory:
        os.chdir(directory)
        try:
            yield Path(directory)
        finally:
            os.chdir(previous)


def encoded(value):
    return base64.b64encode(value.encode()).decode()


class AndroidConfigurationTests(unittest.TestCase):
    def configuration(self, root):
        google = {"project_info": {"project_id": "foodsavr-test"}, "client": [
            {"client_info": {"android_client_info": {"package_name": "com.foodsavr.app"}}}
        ]}
        return {
            "RUNNER_TEMP": str(root), "GITHUB_ENV": str(root / "github-env"),
            "ANDROID_KEYSTORE_B64": encoded("test keystore"),
            "ANDROID_KEYSTORE_PASSWORD": "test-password",
            "ANDROID_KEY_ALIAS": "upload", "ANDROID_KEY_PASSWORD": "test-password",
            "ANDROID_FIREBASE_OPTIONS_B64": encoded("test Firebase options"),
            "ANDROID_GOOGLE_SERVICES_B64": encoded(json.dumps(google)),
            "ANDROID_ENV_B64": encoded("EXAMPLE=test"),
        }

    def test_missing_credentials_fail_before_writing(self):
        with workspace() as root, patch.dict(os.environ, {}, clear=True):
            with self.assertRaisesRegex(ValueError, "Missing GitHub secrets"):
                prepare()
            self.assertEqual(list(root.iterdir()), [])

    def test_restores_private_files_and_exports_only_path(self):
        with workspace() as root, patch.dict(os.environ, self.configuration(root), clear=True):
            prepare()
            self.assertEqual(Path("assets/.env").read_text(), "EXAMPLE=test")
            self.assertEqual((root / "android-upload.jks").stat().st_mode & 0o777, 0o600)
            self.assertEqual((root / "github-env").read_text(), f"ANDROID_KEYSTORE_PATH={root}/android-upload.jks\n")

    def test_wrong_package_and_demo_backend_fail_before_writing(self):
        for original, replacement in [("com.foodsavr.app", "wrong.package"), ("foodsavr-test", "demo-project")]:
            with workspace() as root:
                config = self.configuration(root)
                google = base64.b64decode(config["ANDROID_GOOGLE_SERVICES_B64"]).decode()
                config["ANDROID_GOOGLE_SERVICES_B64"] = encoded(google.replace(original, replacement))
                with patch.dict(os.environ, config, clear=True), self.assertRaises(ValueError):
                    prepare()
                self.assertEqual(list(root.iterdir()), [])


class Response(io.BytesIO):
    def __init__(self, body=None, headers=None):
        super().__init__(json.dumps(body or {}).encode())
        self.headers = headers or {}


class DriveUploadTests(unittest.TestCase):
    def test_streams_apk_to_selected_folder_and_records_download_link(self):
        with workspace() as root:
            apk = root / "test.apk"
            apk.write_bytes(b"apk payload")
            requests = []

            def send(request, **_):
                requests.append(request)
                if len(requests) == 1:
                    self.assertEqual(request.host, "oauth2.googleapis.com")
                    return Response({"access_token": "test-access-token"})
                if len(requests) == 2:
                    self.assertEqual(json.loads(request.data)["parents"], ["folder-123"])
                    return Response(headers={"Location": "https://www.googleapis.com/upload/session"})
                self.assertEqual(request.method, "PUT")
                self.assertEqual(b"".join(request.data), b"apk payload")
                return Response({"id": "file-123"})

            config = {"GOOGLE_DRIVE_FOLDER_ID": "folder-123", "GOOGLE_DRIVE_OAUTH_JSON": json.dumps({
                "client_id": "test-client", "client_secret": "test-secret", "refresh_token": "test-refresh",
            }), "GITHUB_STEP_SUMMARY": str(root / "summary")}
            with patch.dict(os.environ, config), patch("upload_drive.urlopen", side_effect=send):
                upload(apk)
            self.assertEqual(len(requests), 3)
            summary = (root / "summary").read_text()
            self.assertIn("https://drive.google.com/file/d/file-123/view", summary)
            self.assertNotIn("test-access-token", summary)

    def test_folder_url_rejected_before_network_access(self):
        with patch.dict(os.environ, {"GOOGLE_DRIVE_FOLDER_ID": "https://drive.google.com/folder"}):
            with patch("upload_drive.urlopen") as network, self.assertRaises(ValueError):
                upload(Path("unused.apk"))
            network.assert_not_called()


if __name__ == "__main__":
    unittest.main()
