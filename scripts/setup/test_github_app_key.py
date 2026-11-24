#!/usr/bin/env python3
"""Tests for scripts/github_app_key.py (local PEM validation and installation token check)."""

from __future__ import annotations

import base64
from io import BytesIO
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import github_app_key as gak  # noqa: E402


class GithubAppKeyTest(unittest.TestCase):
    pkcs8_pem: str
    pkcs1_pem: str

    @classmethod
    def setUpClass(cls):
        cls.pkcs8_pem = subprocess.run(
            ["openssl", "genrsa", "2048"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        cls.pkcs1_pem = subprocess.run(
            ["openssl", "rsa", "-traditional"],
            input=cls.pkcs8_pem,
            capture_output=True,
            text=True,
            check=True,
        ).stdout

    def test_valid_key_passes_cryptography_and_openssl_paths(self):
        for pem in (self.pkcs8_pem, self.pkcs1_pem):
            with self.subTest(header=pem.splitlines()[0]):
                canonical = gak.validate(pem)
                self.assertTrue(canonical.endswith("\n"))
                with patch.object(gak, "HAS_CRYPTOGRAPHY", False):
                    self.assertEqual(gak.validate(pem), canonical)

    def test_truncated_key_is_rejected(self):
        lines = self.pkcs1_pem.strip().splitlines()
        without_end = "\n".join(lines[:-1]) + "\n"
        dropped_body = "\n".join([lines[0], *lines[1:4], lines[-1]]) + "\n"
        for bad in (without_end, dropped_body):
            with self.subTest(bad=bad.splitlines()[-1]):
                with self.assertRaises(ValueError):
                    gak.validate(bad)
                with patch.object(gak, "HAS_CRYPTOGRAPHY", False), self.assertRaises(ValueError):
                    gak.validate(bad)

    def test_literal_escaped_newlines_and_stray_quotes_are_rejected(self):
        escaped = self.pkcs1_pem.strip().replace("\n", "\\n")
        with self.assertRaisesRegex(ValueError, r"\\n"):
            gak.validate(escaped)

        double_quoted = f'"{self.pkcs1_pem.strip()}"'
        single_quoted = f"'{self.pkcs1_pem.strip()}'"
        for quoted in (double_quoted, single_quoted):
            with self.assertRaisesRegex(ValueError, "quotes"):
                gak.validate(quoted)

    def test_mint_jwt_and_verify_installation_token_with_mocked_http(self):
        jwt_token = gak.mint_app_jwt("12345", self.pkcs1_pem, now=1_700_000_000)
        header_b64, payload_b64, sig_b64 = jwt_token.split(".")
        header = json.loads(base64.urlsafe_b64decode(header_b64 + "=="))
        payload = json.loads(base64.urlsafe_b64decode(payload_b64 + "=="))
        self.assertEqual(header, {"alg": "RS256", "typ": "JWT"})
        self.assertEqual(payload["iss"], "12345")
        self.assertTrue(len(sig_b64) > 20)

        with patch.object(gak, "HAS_CRYPTOGRAPHY", False):
            openssl_jwt = gak.mint_app_jwt("12345", self.pkcs1_pem, now=1_700_000_000)
        self.assertEqual(openssl_jwt.split(".")[:2], [header_b64, payload_b64])

        open_url = Mock(side_effect=[
            BytesIO(b'{"id": 987654}'),
            BytesIO(b'{"token": "ghs_secret_install_token"}'),
        ])
        ok, message = gak.verify_installation_token(
            self.pkcs1_pem,
            app_id="12345",
            repo="alice/foodsavr",
            open_url=open_url,
        )
        self.assertTrue(ok)
        self.assertEqual(message, "Verified GitHub App 12345 on alice/foodsavr (installation token minted).")
        self.assertNotIn("ghs_secret_install_token", message)
        self.assertNotIn("PRIVATE KEY", message)

        req_get = open_url.call_args_list[0].args[0]
        self.assertEqual(req_get.get_method(), "GET")
        self.assertEqual(req_get.full_url, "https://api.github.com/repos/alice/foodsavr/installation")
        req_post = open_url.call_args_list[1].args[0]
        self.assertEqual(req_post.get_method(), "POST")
        self.assertEqual(req_post.full_url, "https://api.github.com/app/installations/987654/access_tokens")

    def test_verify_installation_token_reports_single_next_action_on_failure(self):
        unauth = HTTPError("u", 401, "Unauthorized", {}, BytesIO(b"{}"))
        ok_401, msg_401 = gak.verify_installation_token(
            self.pkcs1_pem,
            app_id="12345",
            repo="alice/foodsavr",
            open_url=Mock(side_effect=unauth),
        )
        self.assertFalse(ok_401)
        self.assertEqual(len(msg_401.splitlines()), 1)
        self.assertIn("https://github.com/settings/apps", msg_401)

        not_installed = HTTPError("u", 404, "Not Found", {}, BytesIO(b"{}"))
        ok_404, msg_404 = gak.verify_installation_token(
            self.pkcs1_pem,
            app_id="12345",
            repo="alice/foodsavr",
            open_url=Mock(side_effect=not_installed),
        )
        self.assertFalse(ok_404)
        self.assertEqual(len(msg_404.splitlines()), 1)
        self.assertIn("https://github.com/alice/foodsavr/settings/installations", msg_404)

    def test_repo_and_installation_id_are_mutually_exclusive(self):
        open_url = Mock()
        ok, message = gak.verify_installation_token(
            self.pkcs1_pem, app_id="12345", repo="alice/foodsavr",
            installation_id="987654", open_url=open_url,
        )
        self.assertFalse(ok)
        self.assertIn("Choose either", message)
        open_url.assert_not_called()

        with patch.object(sys, "stderr"), self.assertRaises(SystemExit) as error:
            gak.main([
                "verify", "-", "--app-id", "12345", "--repo", "alice/foodsavr",
                "--installation-id", "987654",
            ])
        self.assertEqual(error.exception.code, 2)

    def test_cli_validate_command_with_temp_pem_file(self):
        with tempfile.TemporaryDirectory() as td:
            good = Path(td) / "good.pem"
            good.write_text(self.pkcs1_pem, encoding="utf-8")
            self.assertEqual(gak.main(["validate", str(good)]), 0)

            bad = Path(td) / "escaped.pem"
            bad.write_text(self.pkcs1_pem.strip().replace("\n", "\\n"), encoding="utf-8")
            self.assertEqual(gak.main(["validate", str(bad)]), 1)


if __name__ == "__main__":
    unittest.main()
