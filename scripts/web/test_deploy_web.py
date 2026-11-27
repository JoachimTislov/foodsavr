#!/usr/bin/env python3
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import DEFAULT, MagicMock, Mock, call, patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import deploy_web as dw  # noqa: E402
import hosting_storage_guard as guard  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


CHANNELS = {"test": ["develop", "daily", "weekly"], "production": ["stable"], "staging": []}


class HostingStorageGuardTest(unittest.TestCase):
    def run_guard(self, target, responses, expected_exit):
        def api(method, path, params=""):
            if method == "DELETE":
                return {}
            response = responses[path, params]
            if isinstance(response, Exception):
                raise response
            return response

        with patch.dict(os.environ, {"PROJECT_ID": "demo-project", "SITE_ID": "selected"}, clear=True), \
                patch.object(sys, "argv", ["guard", target, "1"]), \
                patch.object(guard, "token", return_value="test-token"), \
                patch.object(guard, "call", side_effect=api) as request, \
                redirect_stdout(StringIO()), self.assertRaises(SystemExit) as error:
            guard.main()
        self.assertEqual(error.exception.code, expected_exit)
        return [args[1] for args in (entry.args for entry in request.call_args_list) if args[0] == "DELETE"]

    def pages(self, sibling_page):
        page = "?pageSize=100"
        return {
            ("projects/demo-project/sites", page): {
                "sites": [{"name": "projects/123/sites/selected"}], "nextPageToken": "p+/=",
            },
            ("projects/demo-project/sites", page + "&pageToken=p%2B%2F%3D"): {
                "sites": [{"name": "projects/123/sites/sibling"}],
            },
            ("sites/selected/versions", page): {"versions": [
                {"name": "sites/selected/versions/one", "status": "FINALIZED", "versionBytes": str(guard.GB)},
            ]},
            ("sites/sibling/versions", page): {"versions": [], "nextPageToken": "more"},
            ("sites/sibling/versions", page + "&pageToken=more"): sibling_page,
            ("sites/selected/channels/live/releases", page): {},
            ("sites/selected/channels", page): {"channels": [{"name": "sites/selected/channels/old"}]},
            ("sites/selected/channels/old/releases", page): {
                "releases": [{"version": {"name": "sites/selected/versions/one"}}],
            },
        }

    def test_sibling_storage_blocks_preview_and_only_selected_site_is_cleaned(self):
        pages = self.pages({"versions": [
            {"name": "sites/sibling/versions/two", "status": "FINALIZED", "versionBytes": str(8 * guard.GB)},
        ]})
        self.assertEqual(self.run_guard("preview", pages, 3), ["sites/selected/channels/old"])

    def test_finalized_version_without_bytes_counts_as_zero(self):
        # ProtoJSON omits versionBytes when it is 0; the guard must match an explicit 0.
        explicit = self.pages({"versions": [
            {"name": "sites/sibling/versions/two", "status": "FINALIZED", "versionBytes": str(8 * guard.GB)},
            {"name": "sites/sibling/versions/empty", "status": "FINALIZED", "versionBytes": "0"},
        ]})
        omitted = self.pages({"versions": [
            {"name": "sites/sibling/versions/two", "status": "FINALIZED", "versionBytes": str(8 * guard.GB)},
            {"name": "sites/sibling/versions/empty", "status": "FINALIZED"},
        ]})
        self.assertEqual(self.run_guard("preview", omitted, 3), self.run_guard("preview", explicit, 3))

    def test_non_integer_version_bytes_blocks_cleanup(self):
        pages = self.pages({"versions": [
            {"name": "sites/sibling/versions/two", "status": "FINALIZED", "versionBytes": "8GB"},
        ]})
        self.assertEqual(self.run_guard("preview", pages, 2), [])

    def test_live_cleanup_preserves_latest_three_versions_and_sibling_site(self):
        pages = self.pages({"versions": [
            {"name": "sites/sibling/versions/other", "status": "FINALIZED", "versionBytes": str(9 * guard.GB)},
        ]})
        names = [f"sites/selected/versions/{n}" for n in range(4)]
        query = "?pageSize=100"
        pages["sites/selected/versions", query] = {"versions": [
            {"name": name, "status": "FINALIZED", "versionBytes": str(guard.GB)} for name in names
        ]}
        pages["sites/selected/channels/live/releases", query] = {
            "releases": [{"version": {"name": name}} for name in names],
        }
        pages["sites/selected/channels", query] = {}
        self.assertEqual(self.run_guard("live", pages, 2), [names[-1]])

    def test_foreign_channel_name_in_selected_inventory_blocks_cleanup(self):
        pages = self.pages({"versions": []})
        pages["sites/selected/channels", "?pageSize=100"] = {
            "channels": [{"name": "sites/sibling/channels/old"}],
        }
        self.assertEqual(self.run_guard("preview", pages, 2), [])

    def test_missing_or_failed_continuation_blocks_cleanup(self):
        self.assertEqual(self.run_guard("preview", self.pages(SystemExit(2)), 2), [])

    def test_omitted_resource_list_is_an_empty_page(self):
        # ProtoJSON omits empty repeated fields, including on intermediate and terminal pages.
        responses = {"?pageSize=100": {"nextPageToken": "more"},
                     "?pageSize=100&pageToken=more": {"rows": [{"name": "a"}]},
                     "?pageSize=100&pageToken=last": {}}
        responses["?pageSize=100&pageToken=more"]["nextPageToken"] = "last"
        with patch.object(guard, "call", side_effect=lambda m, path, params="": responses[params]):
            self.assertEqual(guard.list_all("p", "rows"), [{"name": "a"}])

    def test_error_body_on_continuation_blocks_cleanup(self):
        self.assertEqual(self.run_guard("preview", self.pages({"error": {}}), 2), [])


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
            self.assertEqual(dw.build_defines("production"), [
                "--dart-define=FLAVOR=production", "--dart-define=DEPLOY_ENVIRONMENT=production",
            ])
            warned.assert_called_once()
        full = dw.build_defines("staging", "key", "sentry", "https://e")
        self.assertEqual(full, [
            "--dart-define=FLAVOR=production",
            "--dart-define=DEPLOY_ENVIRONMENT=staging",
            "--dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=key",
            "--dart-define=ERROR_REPORTER=sentry",
            "--dart-define=ERROR_COLLECTOR_ENDPOINT=https://e",
        ])

    def test_hosted_access_and_legal_environment_defines(self):
        self.assertEqual(
            dw.build_defines("test", "key", access_code="fixture-code", legal_environment="test"),
            [
                "--dart-define=FLAVOR=production",
                "--dart-define=DEPLOY_ENVIRONMENT=test",
                "--dart-define=WEB_ACCESS_CODE=fixture-code",
                "--dart-define=LEGAL_ENVIRONMENT=test",
                "--dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=key",
            ],
        )

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

    def build(self, returncode=0, echo=""):
        """Run cmd_build with every tool faked; report what the Flutter build saw."""
        seen = {"dotenv": [], "defines": None}
        target = dw.ROOT / "assets/.env"

        def run(cmd, **kwargs):
            if cmd[0] in ("flutter", "dart"):
                seen["dotenv"].append(target.read_text())
            return subprocess.CompletedProcess(cmd, 0, "{}", "")

        def popen(cmd, **kwargs):
            self.assertEqual(cmd[:3], ["flutter", "build", "web"])
            seen["dotenv"].append(target.read_text())
            seen["defines"] = [a for a in cmd if a.startswith("--dart-define=BUNDLED_ENV_B64=")]
            process = MagicMock(returncode=returncode, stdout=iter([echo.format(cmd=" ".join(cmd))]))
            process.__enter__.return_value = process
            return process

        output = StringIO()
        with patch.dict(os.environ, {"PROJECT_ID": "p", "WEB_APP_ID": "w", "FLAVOR": "test"}), \
                patch.object(dw, "run", side_effect=run), patch.object(dw.subprocess, "Popen", side_effect=popen), \
                patch.object(dw, "build_revision", return_value=""), patch.object(dw, "write_release_metadata"), \
                patch.object(dw, "write_landing_config"), redirect_stdout(output), redirect_stderr(output):
            try:
                dw.cmd_build()
            except SystemExit as error:
                print(error)
                seen["error"] = str(error)
        seen["output"] = output.getvalue()
        return seen

    def dotenv(self, content):
        target = dw.ROOT / "assets/.env"
        target.parent.mkdir(exist_ok=True)
        target.write_text(content)
        return target

    def assert_bundled(self, seen, content):
        encoded = base64.b64encode(content).decode()
        self.assertEqual(seen["defines"], [f"--dart-define=BUNDLED_ENV_B64={encoded}"])
        self.assertEqual(set(seen["dotenv"]), {""})
        self.assertNotIn(encoded, seen["output"])
        self.assertNotIn(content.decode().strip(), seen["output"])

    def test_base64_source_is_bundled_as_one_line(self):
        self.env(WEB_ENV_B64=" QT1wYXls\r\nb2Fk\nCg==\n")
        self.assert_bundled(self.build(), b"A=payload\n")

    def test_file_source_is_bundled(self):
        source = Path(self.tmp.name) / "src.env"
        source.write_text("A=payload\n" * 20)
        self.env(WEB_ENV_FILE=str(source))
        seen = self.build()
        self.assert_bundled(seen, b"A=payload\n" * 20)
        self.assertNotIn("\n", seen["defines"][0])

    def test_assets_dotenv_as_the_source_is_read_before_blanking_and_restored(self):
        target = self.dotenv("A=payload\n")
        self.env(WEB_ENV_FILE=str(target))
        self.assert_bundled(self.build(), b"A=payload\n")
        self.assertEqual(target.read_text(), "A=payload\n")

    def test_local_dotenv_is_not_published_without_a_source(self):
        target = self.dotenv("A=local\n")
        self.env()
        seen = self.build()
        self.assertEqual(seen["defines"], [])
        self.assertEqual(set(seen["dotenv"]), {""})
        self.assertEqual(target.read_text(), "A=local\n")

    def test_empty_env_omits_the_define(self):
        source = Path(self.tmp.name) / "empty.env"
        source.write_text("\n")
        for values in ({"WEB_ENV_FILE": str(source)}, {"WEB_ENV_B64": "\n"}, {"WEB_ENV_B64": "Cg=="}):
            with self.subTest(values=values):
                self.env(WEB_ENV_FILE="", WEB_ENV_B64="")
                self.env(**values)
                seen = self.build()
                self.assertEqual(seen["defines"], [])
                self.assertEqual(set(seen["dotenv"]), {""})

    def test_invalid_sources_fail_before_building(self):
        for values, message in (
            ({"WEB_ENV_B64": "!!!!"}, "WEB_ENV_B64 is not valid Base64"),
            ({"WEB_ENV_B64": "//79"}, "not valid UTF-8"),
            ({"WEB_ENV_FILE": "/nonexistent.env"}, "does not exist"),
        ):
            with self.subTest(values=values):
                target = self.dotenv("A=1\n")
                self.env(WEB_ENV_FILE="", WEB_ENV_B64="")
                self.env(**values)
                seen = self.build()
                self.assertIn(message, seen["error"])
                self.assertEqual(seen["dotenv"], [])
                self.assertEqual(target.read_text(), "A=1\n")

    def test_build_output_and_failure_never_show_the_payload(self):
        target = self.dotenv("A=local\n")
        encoded = base64.b64encode(b"A=payload\n").decode()
        self.env(WEB_ENV_B64=encoded)
        seen = self.build(returncode=1, echo="Command: {cmd}\n")
        self.assertIn("flutter build web failed with exit code 1", seen["error"])
        self.assertIn("BUNDLED_ENV_B64=<redacted>", seen["output"])
        self.assertNotIn(encoded, seen["output"])
        self.assertEqual(target.read_text(), "A=local\n")

    def test_preserved_restores_and_removes_files(self):
        (dw.ROOT / "lib").mkdir()
        (dw.ROOT / "lib/firebase_options.dart").write_text("mine")
        with dw.preserved(("lib/firebase_options.dart", "firebase.json")):
            (dw.ROOT / "lib/firebase_options.dart").write_text("generated")
            (dw.ROOT / "firebase.json").write_text("{}")
        self.assertEqual((dw.ROOT / "lib/firebase_options.dart").read_text(), "mine")
        self.assertFalse((dw.ROOT / "firebase.json").exists())

    def test_release_metadata_identifies_the_bundle(self):
        bundle = b"compiled app"
        (dw.ROOT / "main.dart.js").write_bytes(bundle)
        dw.write_release_metadata(dw.ROOT, "a" * 40)
        self.assertEqual(json.loads((dw.ROOT / "release.json").read_text()), {
            "revision": "a" * 40,
            "main_bundle_sha256": hashlib.sha256(bundle).hexdigest(),
        })

    def test_write_landing_config_follows_the_environment(self):
        about_dir = dw.ROOT / "build/web/about"
        about_dir.mkdir(parents=True)
        out = about_dir / "config.js"
        for environment in ("test", "staging", "production"):
            with patch.dict(os.environ, {}, clear=True), patch.object(dw, "run") as run:
                dw.write_landing_config(out, environment)
                run.assert_called_once()
                args, kwargs = run.call_args
                self.assertEqual(args[0], ["python3", "scripts/web/write_landing_config.py", str(out)])
                self.assertEqual(kwargs["env"]["LEGAL_ENVIRONMENT"], environment)
        with patch.dict(os.environ, {"LEGAL_ENVIRONMENT": "test"}, clear=True), patch.object(dw, "run") as run:
            dw.write_landing_config(out, "production")
            self.assertEqual(run.call_args.kwargs["env"]["LEGAL_ENVIRONMENT"], "test")


class DeployTest(unittest.TestCase):
    def test_sourcemap_upload_selects_the_project_explicitly(self):
        with patch.dict(os.environ, {"PROJECT_ID": "selected", "WEB_APP_ID": "web-id"}), patch.object(dw, "run") as run:
            dw.cmd_sourcemaps()
            run.assert_called_once_with(dw.firebase(
                "crashlytics:sourcemap:upload", "--app", "web-id", "--project", "selected", "--clean", "build/web"
            ))

    def test_local_live_blaze_provisions_flutter_then_cleans_maps_before_hosting(self):
        with patch.dict(os.environ, {"PATH": "/usr/bin", "FIREBASE_PLAN": "blaze"}, clear=True), \
                patch.multiple(dw, **{name: DEFAULT for name in (
                    "pinned_flutter_dir", "manifest_env", "environment_channels", "check_firebase_login", "actions_variable",
                    "preserved", "cmd_build", "cmd_sourcemaps", "cmd_guard", "cmd_deploy",
                )}) as mocks:
            order = Mock()
            for name, mock in mocks.items():
                order.attach_mock(mock, name)
            mocks["pinned_flutter_dir"].return_value = "/pinned/bin"

            def manifest_env(env_name, channel):
                self.assertEqual(os.environ["PATH"].split(os.pathsep)[0], "/pinned/bin")
                self.assertEqual((env_name, channel), ("production", "stable"))
                return {"PROJECT_ID": "selected", "WEB_APP_ID": "web-id"}

            mocks["environment_channels"].return_value = {"production": ["stable"]}

            mocks["manifest_env"].side_effect = manifest_env
            mocks["preserved"].return_value = MagicMock()
            mocks["actions_variable"].return_value = ""
            mocks["cmd_guard"].return_value = 0
            with redirect_stdout(StringIO()):
                self.assertEqual(dw.main(["local", "--env", "production", "--branch", "develop", "--yes"]), 0)
        self.assertEqual(order.mock_calls[-5:-1], [
            call.cmd_build(), call.cmd_sourcemaps(), call.cmd_guard(), call.cmd_deploy(),
        ])

    def test_guard_failure_never_reports_fit(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {
            "PROJECT_ID": "selected", "TARGET": "live", "ACCESS_TOKEN": "",
            "PATH": tmp, "GITHUB_OUTPUT": str(Path(tmp) / "output"),
        }):
            python = Path(tmp) / "python3"
            python.symlink_to(sys.executable)
            self.assertNotEqual(dw.cmd_guard(), 0)
            self.assertNotIn("fits=", (Path(tmp) / "output").read_text())

    def test_storage_guard_stops_for_unusable_gcloud_credentials(self):
        for failure in (FileNotFoundError(), subprocess.CalledProcessError(1, "gcloud")):
            with self.subTest(failure=failure), patch.dict(os.environ, {"ACCESS_TOKEN": ""}), \
                    patch.object(guard.subprocess, "check_output", side_effect=failure):
                with self.assertRaisesRegex(SystemExit, "gcloud auth login"):
                    guard.token()

    def test_local_channel_comes_from_the_flag_then_the_environment(self):
        namespace = Mock(env="test", channel="", target="live", branch="b", expires="4h", web_env_file="")
        with patch.dict(os.environ, {"CHANNEL": "daily"}), \
                patch.object(dw, "environment_channels", return_value=CHANNELS), \
                patch.object(dw, "manifest_env", return_value={
                    "PROJECT_ID": "p", "WEB_APP_ID": "w", "SITE_ID": "p-daily", "CHANNEL": "daily", "VAR_SUFFIX": "_TEST",
                }) as manifest:
            settings, suffix = dw.local_settings(namespace)
        manifest.assert_called_once_with("test", "daily")
        self.assertEqual((settings["SITE_ID"], settings["RELEASE_CHANNEL"], suffix), ("p-daily", "daily", "_TEST"))

    def test_live_deploy_refuses_a_channel_the_environment_does_not_deploy(self):
        with patch.object(dw, "environment_channels", return_value=CHANNELS):
            for env_name, channel in (("test", "stable"), ("production", "develop"), ("staging", "")):
                with self.subTest(env=env_name, channel=channel):
                    with self.assertRaises(SystemExit) as raised:
                        dw.select_channel(env_name, channel, "live")
                    message = str(raised.exception)
                    self.assertIn("does not deploy channel", message)
                    self.assertIn("ENV=test CHANNEL=develop|daily|weekly; ENV=production CHANNEL=stable", message)
            self.assertEqual(dw.select_channel("test", "", "live"), "develop")
            self.assertEqual(dw.select_channel("production", "stable", "live"), "stable")

    def test_previews_validate_explicit_channel_and_default_to_base_site(self):
        with patch.object(dw, "environment_channels", return_value=CHANNELS) as channels:
            self.assertEqual(dw.select_channel("staging", "", "preview"), "")
            channels.assert_not_called()
            self.assertEqual(dw.select_channel("test", "daily", "preview"), "daily")
            with self.assertRaises(SystemExit):
                dw.select_channel("test", "stable", "preview")

    def test_unprovisioned_environment_is_refused(self):
        done = subprocess.CompletedProcess([], 0, "PROVISIONED='false'\nFLAVOR='production'\n", "")
        with patch.object(dw.subprocess, "run", return_value=done):
            with self.assertRaisesRegex(SystemExit, "not provisioned yet; run make setup"):
                dw.manifest_env("production", "stable")

    def test_web_config_writes_the_selected_environment_options(self):
        config = '{"result":{"sdkConfig":{"projectId":"prod","appId":"1:2:web:3","apiKey":"k"}}}'
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "lib").mkdir()
            env = {**os.environ, "DEPLOY_ENVIRONMENT": "production", "PROJECT_ID": "prod", "SITE_ID": "prod-site"}
            subprocess.run([sys.executable, str(ROOT / "scripts/web/write_web_config.py")], cwd=tmp,
                           input=config, text=True, check=True, env=env)
            prod = (Path(tmp) / "lib/firebase_options_prod.dart").read_text()
            self.assertIn("class ProdFirebaseOptions {", prod)
            self.assertIn("static const bool configured = true;", prod)
            self.assertFalse((Path(tmp) / "lib/firebase_options.dart").exists())
            self.assertEqual(json.loads((Path(tmp) / "firebase.json").read_text())["hosting"]["site"], "prod-site")

            env["DEPLOY_ENVIRONMENT"] = "test"
            env["PROJECT_ID"] = "test-project"
            failed = subprocess.run([sys.executable, str(ROOT / "scripts/web/write_web_config.py")], cwd=tmp,
                                    input=config, text=True, env=env, capture_output=True)
            self.assertNotEqual(failed.returncode, 0)
            self.assertIn("expected 'test-project'", failed.stderr)
            self.assertFalse((Path(tmp) / "lib/firebase_options.dart").exists())

    def test_hosting_config_excludes_source_maps_even_if_cleanup_leaves_some(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "lib").mkdir()
            subprocess.run([sys.executable, str(ROOT / "scripts/web/write_web_config.py")], cwd=tmp,
                           input='{"result":{"sdkConfig":{"projectId":"selected"}}}', text=True, check=True)
            hosting = json.loads((Path(tmp) / "firebase.json").read_text())["hosting"]
            self.assertIn("**/*.js.map", hosting["ignore"])


RELEASE = ROOT / ".github/workflows/release.yml"


def hosting_jobs() -> str:
    """The plan (environment resolution) and hosting-deploy jobs of release.yml."""
    text = RELEASE.read_text()
    jobs = text[text.index("\njobs:\n"):]
    parts = re.split(r"(?m)^(?=  [a-z][a-z0-9-]*:\n)", jobs)
    return "".join(p for p in parts if p.startswith(("  plan:", "  hosting-deploy:")))


class LiveUrlOutputTest(unittest.TestCase):
    def test_only_a_successful_live_deploy_reports_its_site_url(self):
        for site, expected in (("proj-daily", "https://proj-daily.web.app"), ("", "https://proj.web.app")):
            with self.subTest(site=site), tempfile.TemporaryDirectory() as directory:
                output = Path(directory) / "output"
                env = {"PROJECT_ID": "proj", "SITE_ID": site, "TARGET": "live", "GITHUB_OUTPUT": str(output),
                       "GITHUB_STEP_SUMMARY": ""}
                with patch.dict(os.environ, env), patch.object(dw, "run"), redirect_stdout(StringIO()):
                    dw.cmd_deploy()
                self.assertEqual(output.read_text(), f"url={expected}\n")
                output.unlink()
                failure = subprocess.CalledProcessError(1, "firebase")
                with patch.dict(os.environ, env), patch.object(dw, "run", side_effect=failure), \
                        self.assertRaises(subprocess.CalledProcessError):
                    dw.cmd_deploy()
                self.assertFalse(output.exists())


class WorkflowContractTest(unittest.TestCase):
    """release.yml's hosting jobs delegate to this script instead of inlining the logic."""

    def test_workflow_calls_the_script(self):
        text = hosting_jobs()
        for command in ("deploy_web.py build", "deploy_web.py guard", "deploy_web.py deploy"):
            self.assertIn(command, text)
        self.assertNotIn("flutter build web", text)
        self.assertNotIn("hosting:channel:deploy", text)

    def test_no_flutter_workflow_exports_the_actions_channel_variable(self):
        # flutter-action's setup.sh prefers an inherited CHANNEL over its `channel` input.
        for path in sorted((ROOT / ".github").rglob("*.yml")):
            text = path.read_text()
            if "subosito/flutter-action" in text:
                with self.subTest(path=path.name):
                    self.assertNotRegex(text, r"(?m)^\s+CHANNEL:\s")

    def test_missing_config_fails_and_names_the_bypass_and_fix(self):
        # #531: an enabled Hosting deployment with invalid configuration fails the
        # job instead of skipping green; the bypass and fix stay in the diagnostic.
        text = hosting_jobs()
        self.assertIn("make deploy-web ENV=$FLAVOR${RELEASE_CHANNEL:+ CHANNEL=$RELEASE_CHANNEL}", text)
        self.assertIn("make setup", text)
        self.assertIn('>> "$GITHUB_STEP_SUMMARY"', text)
        config = text[text.index("- name: Check deploy configuration"):text.index("- name: Checkout code", text.index("Check deploy configuration"))]
        self.assertIn("exit 1", config)
        # Only the invalid-config path fails; the valid path exits before it.
        self.assertLess(config.index("exit 0"), config.index("exit 1"))

    def test_deploys_only_with_a_service_account_of_the_resolved_project(self):
        text = hosting_jobs()
        self.assertIn('"${DEPLOY_SA##*@}" != "$PROJECT_ID.iam.gserviceaccount.com"', text)
        steps = text[text.index("- name: Checkout code", text.index("hosting-deploy:")):]
        for step in steps.split("- name: ")[1:]:
            self.assertIn("steps.config.outputs.ready == 'true'", step, step.splitlines()[0])

    def test_release_channels_trigger_and_resolve_through_the_manifest(self):
        self.assertIn("branches: [develop, daily, weekly, stable]", RELEASE.read_text())
        text = hosting_jobs()
        self.assertIn('levels.dart env --channel "$channel"', text)
        self.assertIn("PROVISIONED=false", text)

    def test_explicit_environment_never_falls_back_to_its_default_site(self):
        text = hosting_jobs()
        explicit = text[text.index('elif ! dart run bin/levels.dart env --env "$env_name" --channel "$channel"'):]
        explicit = explicit[:explicit.index("\n          fi\n")]
        self.assertIn("::error::", explicit)
        self.assertIn("Valid live deploys", explicit)
        self.assertIn("exit 1", explicit)
        self.assertNotIn('--env "$env_name" --format github', explicit)

if __name__ == "__main__":
    unittest.main()
