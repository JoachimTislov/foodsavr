from contextlib import redirect_stdout
from io import BytesIO, StringIO
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError

import facebook_provider as fp


class FacebookProviderTest(unittest.TestCase):
    project = "demo-project"
    app_id = "fb-app-123"
    app_secret = "fb-secret-xyz"
    console_url = "https://console.firebase.google.com/project/demo-project/authentication/providers"

    def check(self, open_url, app_id=None):
        return fp.sync_facebook_provider(
            self.project,
            self.app_id if app_id is None else app_id,
            self.app_secret,
            get_token=lambda _acc: "tok-1",
            open_url=open_url,
        )

    def test_check_is_read_only_and_names_terraform_as_the_fix(self):
        not_found = HTTPError("u", 404, "Not Found", {}, BytesIO(b"{}"))
        open_url = Mock(side_effect=[not_found])
        ok, message = self.check(open_url)
        self.assertFalse(ok)
        self.assertIn("make infra-gcp-apply", message)
        self.assertEqual(open_url.call_count, 1)
        request = open_url.call_args_list[0].args[0]
        self.assertEqual(request.get_method(), "GET")
        self.assertTrue(request.full_url.endswith(f"/{self.project}/defaultSupportedIdpConfigs/facebook.com"))
        self.assertEqual(request.get_header("X-goog-user-project"), self.project)
        self.assertIsNone(request.data)

    def test_enabled_with_matching_app_id_is_ok_and_ignores_the_live_secret(self):
        body = {"enabled": True, "clientId": self.app_id, "clientSecret": "live-secret-value"}
        open_url = Mock(return_value=BytesIO(json.dumps(body).encode()))
        ok, message = self.check(open_url)
        self.assertTrue(ok)
        self.assertEqual(message, "facebook.com is enabled")
        self.assertNotIn("live-secret-value", message)

    def test_disabled_or_other_app_id_reports_without_writing(self):
        for body, expected in (
            ({"enabled": False, "clientId": self.app_id}, "facebook.com is disabled"),
            ({"enabled": True, "clientId": "other-app"}, "different app ID"),
        ):
            with self.subTest(body=body):
                open_url = Mock(return_value=BytesIO(json.dumps(body).encode()))
                ok, message = self.check(open_url)
                self.assertFalse(ok)
                self.assertIn(expected, message)
                self.assertEqual(open_url.call_count, 1)
                self.assertEqual(open_url.call_args_list[0].args[0].get_method(), "GET")

    def test_permission_error_and_missing_token_fall_back_to_console_url_without_leaking_secrets(self):
        forbidden = HTTPError("u", 403, "Forbidden", {}, BytesIO(b'{"error": {"code": 403}}'))
        ok, message = fp.sync_facebook_provider(
            self.project,
            self.app_id,
            self.app_secret,
            get_token=lambda _acc: "tok-1",
            open_url=Mock(side_effect=forbidden),
        )
        self.assertFalse(ok)
        self.assertIn(self.console_url, message)
        self.assertNotIn(self.app_id, message)
        self.assertNotIn(self.app_secret, message)

        ok_no_tok, msg_no_tok = fp.sync_facebook_provider(
            self.project,
            self.app_id,
            self.app_secret,
            get_token=lambda _acc: "",
            open_url=Mock(),
        )
        self.assertFalse(ok_no_tok)
        self.assertIn(self.console_url, msg_no_tok)

    def test_cli_reads_dotenv_without_printing_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / ".env").write_text(
                f"FACEBOOK_APP_ID='{self.app_id}'\nFACEBOOK_APP_SECRET='{self.app_secret}'\n",
                encoding="utf-8",
            )
            open_url = Mock(return_value=BytesIO(json.dumps({
                "enabled": True,
                "clientId": self.app_id,
            }).encode()))
            out = StringIO()
            with (
                patch.object(fp, "ROOT", root),
                patch.dict(os.environ, {}, clear=True),
                patch.object(fp, "identity_toolkit_token", return_value="tok-1"),
                patch.object(fp, "urlopen", open_url),
                redirect_stdout(out),
            ):
                code = fp.main([self.project])
            self.assertEqual(code, 0)
            self.assertEqual(out.getvalue(), "facebook.com is enabled\n")
            self.assertNotIn(self.app_id, out.getvalue())
            self.assertNotIn(self.app_secret, out.getvalue())


if __name__ == "__main__":
    unittest.main()
