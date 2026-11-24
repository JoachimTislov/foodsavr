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

    def test_missing_creates_with_post_and_quota_header(self):
        not_found = HTTPError("u", 404, "Not Found", {}, BytesIO(b"{}"))
        open_url = Mock(side_effect=[not_found, BytesIO(b'{"enabled": true}')])
        ok, message = fp.sync_facebook_provider(
            self.project,
            self.app_id,
            self.app_secret,
            get_token=lambda _acc: "tok-1",
            open_url=open_url,
        )
        self.assertTrue(ok)
        self.assertEqual(message, "facebook.com enabled")
        self.assertEqual(open_url.call_count, 2)

        req_get = open_url.call_args_list[0].args[0]
        self.assertEqual(req_get.get_method(), "GET")
        self.assertTrue(req_get.full_url.endswith(f"/{self.project}/defaultSupportedIdpConfigs/facebook.com"))
        self.assertEqual(req_get.get_header("X-goog-user-project"), self.project)

        req_post = open_url.call_args_list[1].args[0]
        self.assertEqual(req_post.get_method(), "POST")
        self.assertTrue(req_post.full_url.endswith(f"/{self.project}/defaultSupportedIdpConfigs?idpId=facebook.com"))
        self.assertEqual(req_post.get_header("X-goog-user-project"), self.project)
        self.assertEqual(
            json.loads(req_post.data.decode()),
            {"enabled": True, "clientId": self.app_id, "clientSecret": self.app_secret},
        )
        self.assertNotIn(self.console_url, message)
        self.assertNotIn(self.app_secret, message)

    def test_enabled_same_is_idempotent_single_ok_without_patch(self):
        open_url = Mock(return_value=BytesIO(json.dumps({
            "enabled": True,
            "clientId": self.app_id,
            "clientSecret": self.app_secret,
        }).encode()))
        ok, message = fp.sync_facebook_provider(
            self.project,
            self.app_id,
            self.app_secret,
            get_token=lambda _acc: "tok-1",
            open_url=open_url,
        )
        self.assertTrue(ok)
        self.assertEqual(message, "facebook.com is enabled")
        self.assertEqual(open_url.call_count, 1)
        req_get = open_url.call_args_list[0].args[0]
        self.assertEqual(req_get.get_method(), "GET")
        self.assertEqual(req_get.get_header("X-goog-user-project"), self.project)

    def test_enabled_different_client_id_or_secret_updates_with_patch(self):
        for existing in (
            {"enabled": True, "clientId": "other-app", "clientSecret": self.app_secret},
            {"enabled": True, "clientId": self.app_id, "clientSecret": "old-secret"},
        ):
            with self.subTest(existing=existing):
                open_url = Mock(side_effect=[
                    BytesIO(json.dumps(existing).encode()),
                    BytesIO(b'{"enabled": true}'),
                ])
                ok, message = fp.sync_facebook_provider(
                    self.project,
                    self.app_id,
                    self.app_secret,
                    get_token=lambda _acc: "tok-1",
                    open_url=open_url,
                )
                self.assertTrue(ok)
                self.assertEqual(message, "facebook.com enabled")
                self.assertEqual(open_url.call_count, 2)
                req_patch = open_url.call_args_list[1].args[0]
                self.assertEqual(req_patch.get_method(), "PATCH")
                self.assertIn("defaultSupportedIdpConfigs/facebook.com?updateMask=enabled,clientId,clientSecret", req_patch.full_url)
                self.assertEqual(req_patch.get_header("X-goog-user-project"), self.project)
                self.assertEqual(
                    json.loads(req_patch.data.decode()),
                    {"enabled": True, "clientId": self.app_id, "clientSecret": self.app_secret},
                )

    def test_disabled_updates_with_patch_and_check_mode_reports_without_mutating(self):
        open_url = Mock(side_effect=[
            BytesIO(b'{"enabled": false, "clientId": "old"}'),
            BytesIO(b'{"enabled": true}'),
        ])
        ok, message = fp.sync_facebook_provider(
            self.project,
            self.app_id,
            self.app_secret,
            get_token=lambda _acc: "tok-1",
            open_url=open_url,
        )
        self.assertTrue(ok)
        self.assertEqual(message, "facebook.com enabled")
        self.assertEqual(open_url.call_args_list[1].args[0].get_method(), "PATCH")

        check_open = Mock(return_value=BytesIO(b'{"enabled": false}'))
        ok_check, check_msg = fp.sync_facebook_provider(
            self.project,
            self.app_id,
            self.app_secret,
            check=True,
            get_token=lambda _acc: "tok-1",
            open_url=check_open,
        )
        self.assertFalse(ok_check)
        self.assertEqual(check_msg, "facebook.com is disabled")
        self.assertEqual(check_open.call_count, 1)

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
