#!/usr/bin/env python3
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import deploy_web as dw  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


class PureTest(unittest.TestCase):
    def test_channel_name_is_sanitized_and_unique_per_branch(self):
        name = dw.channel_name("Feat/Human_Entry")
        self.assertRegex(name, r"^feat-human-entry-[0-9a-f]{12}$")
        self.assertNotEqual(dw.channel_name("a/b"), dw.channel_name("a-b"))
        self.assertTrue(dw.channel_name("///").startswith("branch-"))
        self.assertLessEqual(len(dw.channel_name("x" * 100)), 27 + 1 + 12)

    def test_channel_name_matches_the_previous_shell_pipeline(self):
        # printf %s "$BRANCH" | tr A-Z a-z | tr -c a-z0-9- - | cut -c1-27 | sed ...; sha256sum | cut -c1-12
        import hashlib
        branch = "release/2026.11"
        expected = f"release-2026-11-{hashlib.sha256(branch.encode()).hexdigest()[:12]}"
        self.assertEqual(dw.channel_name(branch), expected)

    def test_expires_validation(self):
        self.assertEqual(dw.check_expires("4h"), "4h")
        for bad in ("4", "h", "4x", "1d2h", ""):
            with self.assertRaises(SystemExit):
                dw.check_expires(bad)

    def test_defines_include_optional_values_only_when_set(self):
        with patch.object(dw, "warn") as warned:
            self.assertEqual(dw.build_defines("production"), ["--dart-define=FLAVOR=production"])
            warned.assert_called_once()
        full = dw.build_defines("staging", "key", "sentry", "https://e")
        self.assertEqual(full, [
            "--dart-define=FLAVOR=staging",
            "--dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=key",
            "--dart-define=ERROR_REPORTER=sentry",
            "--dart-define=ERROR_COLLECTOR_ENDPOINT=https://e",
        ])

    def test_source_maps_only_for_live_blaze(self):
        self.assertEqual(dw.build_flags("blaze", "live"), ["--release", "--source-maps"])
        self.assertEqual(dw.build_flags("blaze", "preview"), ["--release"])
        self.assertEqual(dw.build_flags("spark", "live"), ["--release"])

    def test_parse_dotenv(self):
        parsed = dw.parse_dotenv("FLAVOR='production'\nVAR_SUFFIX=''\nPROJECT_ID='p'\nnoise\n")
        self.assertEqual(parsed, {"FLAVOR": "production", "VAR_SUFFIX": "", "PROJECT_ID": "p"})

    def test_preview_url(self):
        self.assertEqual(dw.preview_url('{"result": {"site": {"url": "https://x"}}}'), "https://x")


class DotenvTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        patcher = patch.object(dw, "ROOT", Path(self.tmp.name))
        patcher.start()
        self.addCleanup(patcher.stop)

    def env(self, **values):
        patcher = patch.dict(os.environ, {"WEB_ENV_B64": "", "WEB_ENV_FILE": "", **values})
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_empty_when_no_source(self):
        self.env()
        with patch.object(dw, "warn"):
            dw.write_dotenv()
        self.assertEqual((dw.ROOT / "assets/.env").read_text(), "")

    def test_from_file(self):
        source = Path(self.tmp.name) / "src.env"
        source.write_text("A=1\n")
        self.env(WEB_ENV_FILE=str(source))
        dw.write_dotenv()
        self.assertEqual((dw.ROOT / "assets/.env").read_text(), "A=1\n")

    def test_missing_file_fails(self):
        self.env(WEB_ENV_FILE="/nonexistent.env")
        with self.assertRaises(SystemExit):
            dw.write_dotenv()

    def test_from_base64(self):
        self.env(WEB_ENV_B64="QT0xCg==")
        dw.write_dotenv()
        self.assertEqual((dw.ROOT / "assets/.env").read_text(), "A=1\n")

    def test_preserved_restores_and_removes_files(self):
        (dw.ROOT / "lib").mkdir()
        (dw.ROOT / "lib/firebase_options.dart").write_text("mine")
        with dw.preserved(("lib/firebase_options.dart", "firebase.json")):
            (dw.ROOT / "lib/firebase_options.dart").write_text("generated")
            (dw.ROOT / "firebase.json").write_text("{}")
        self.assertEqual((dw.ROOT / "lib/firebase_options.dart").read_text(), "mine")
        self.assertFalse((dw.ROOT / "firebase.json").exists())


class WorkflowContractTest(unittest.TestCase):
    """firebase-hosting.yml delegates to this script instead of inlining the logic."""

    def test_workflow_calls_the_script(self):
        text = (ROOT / ".github/workflows/firebase-hosting.yml").read_text()
        for command in ("deploy_web.py build", "deploy_web.py guard", "deploy_web.py deploy"):
            self.assertIn(command, text)
        self.assertNotIn("flutter build web", text)
        self.assertNotIn("hosting:channel:deploy", text)

    def test_missing_config_fails_when_enabled_and_names_the_bypass(self):
        text = (ROOT / ".github/workflows/firebase-hosting.yml").read_text()
        self.assertIn("make deploy-web ENV=", text)
        self.assertIn("make infra-gcp-apply", text)
        self.assertNotIn("Skipping Firebase Hosting deploy", text)


if __name__ == "__main__":
    unittest.main()
