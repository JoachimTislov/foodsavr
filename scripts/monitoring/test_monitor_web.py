import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

MONITOR = Path(__file__).resolve().parent
SHA = "a" * 40


class MonitorWebTest(unittest.TestCase):
    def test_manual_monitor_uses_develop_without_origin_head_and_no_checkout_sha(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            (root / "test/e2e/node_modules").mkdir(parents=True)
            (root / "scripts/monitoring").mkdir(parents=True)
            node = root / "node"
            node.write_text("""#!/bin/bash
while (( $# )); do
  case "$1" in
    --release-sha) printf '%s' "$2" > probe-sha; shift ;;
    --output) printf '%s\\n' '{"ok":false}' > "$2"; shift ;;
  esac
  shift
done
""")
            node.chmod(0o755)
            (root / "scripts/monitoring/fault_intake.py").write_text(
                'import sys; print("ref=" + sys.argv[sys.argv.index("--ref") + 1])\n'
            )
            (root / "scripts/monitoring/verify_and_close.py").write_text(
                'import sys; print("expected=" + sys.argv[sys.argv.index("--deployed-sha") + 1])\n'
            )
            for sha in ("", SHA):
                with self.subTest(sha=sha):
                    result = subprocess.run(
                        ["bash", str(MONITOR / "monitor_web.sh"), "https://example.com"],
                        cwd=root, env={**os.environ, "PATH": f"{root}{os.pathsep}{os.environ['PATH']}",
                                       "RELEASE_SHA": sha},
                        capture_output=True, text=True,
                    )
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertIn("ref=develop", result.stdout.splitlines())
                    self.assertIn(f"expected={sha}", result.stdout.splitlines())
                    self.assertEqual((root / "probe-sha").read_text(), sha)

    @unittest.skipUnless(shutil.which("node"), "requires Node to run the web probe")
    def test_probe_only_reports_revision_bound_to_loaded_bundle(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            script = root / "scripts/monitoring/probe_web.mjs"
            script.parent.mkdir(parents=True)
            shutil.copyfile(MONITOR / script.name, script)
            package = root / "test/e2e/node_modules/playwright"
            package.mkdir(parents=True)
            (root / "test/e2e/package.json").write_text("{}")
            (package / "index.js").write_text("""
const callbacks = {};
const page = {
  on: (event, callback) => { callbacks[event] = callback; },
  goto: async () => callbacks.requestfinished({
    url: () => 'https://example.com/main.dart.js',
    resourceType: () => 'script',
    response: async () => ({ ok: () => true, body: async () => Buffer.from('loaded bundle') }),
  }),
  title: async () => '',
  locator: () => ({ first: () => ({ waitFor: async () => {} }) }),
  evaluate: async () => [],
  removeAllListeners: () => {},
};
const context = {
  newPage: async () => page,
  request: { get: async (url) => ({
    ok: () => url === 'https://example.com/release.json',
    json: async () => JSON.parse(process.env.TEST_RELEASE_METADATA),
  }) },
};
exports.chromium = {
  launch: async () => ({ newContext: async () => context, close: async () => {} }),
};
""")
            digest = hashlib.sha256(b"loaded bundle").hexdigest()
            for reported_digest, served_revision in [(digest, SHA), ("b" * 64, None)]:
                with self.subTest(reported_digest=reported_digest):
                    result = subprocess.run([
                        "node", str(script), "--url", "https://example.com", "--settle-ms", "0",
                        "--release-sha", "c" * 40,
                    ], cwd=root, capture_output=True, text=True, check=True, env={
                        **os.environ, "TEST_RELEASE_METADATA": json.dumps({
                            "revision": SHA, "main_bundle_sha256": reported_digest,
                        }),
                    })
                    report = json.loads(result.stdout)
                    self.assertTrue(report["ok"])
                    self.assertEqual(report["served_revision"], served_revision)

    @unittest.skipUnless(shutil.which("node"), "requires Node to run the web probe")
    def test_probe_ignores_recaptcha_storage_access_noise(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            script = root / "scripts/monitoring/probe_web.mjs"
            script.parent.mkdir(parents=True)
            shutil.copyfile(MONITOR / script.name, script)
            package = root / "test/e2e/node_modules/playwright"
            package.mkdir(parents=True)
            (root / "test/e2e/package.json").write_text("{}")
            (package / "index.js").write_text("""
const callbacks = {};
const page = {
  on: (event, callback) => { callbacks[event] = callback; },
  goto: async () => {
    callbacks.console({ type: () => 'error', text: () => 'requestStorageAccess: Permission denied.',
      location: () => ({ url: 'https://www.google.com/recaptcha/enterprise/anchor?k=xyz', lineNumber: 1, columnNumber: 1 }) });
    callbacks.console({ type: () => 'error', text: () => 'requestStorageAccess: Permission denied.',
      location: () => ({ url: 'https://www.gstatic.com/recaptcha/releases/v1/recaptcha__en.js', lineNumber: 10, columnNumber: 5 }) });
    callbacks.requestfinished({
      url: () => 'https://example.com/main.dart.js', resourceType: () => 'script',
      response: async () => ({ ok: () => true, body: async () => Buffer.from('loaded bundle') }),
    });
  },
  title: async () => '',
  locator: () => ({ first: () => ({ waitFor: async () => {} }) }),
  evaluate: async () => [],
  removeAllListeners: () => {},
};
const context = {
  newPage: async () => page,
  request: { get: async () => ({ ok: () => false }) },
};
exports.chromium = { launch: async () => ({ newContext: async () => context, close: async () => {} }) };
""")
            result = subprocess.run([
                "node", str(script), "--url", "https://example.com", "--settle-ms", "0",
            ], cwd=root, capture_output=True, text=True, check=True)
            report = json.loads(result.stdout)
            self.assertTrue(report["ok"])
            self.assertEqual(report["raw_findings"]["console_errors"], [])

    @unittest.skipUnless(shutil.which("node"), "requires Node to run the web probe")
    def test_probe_reports_app_origin_storage_access_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            script = root / "scripts/monitoring/probe_web.mjs"
            script.parent.mkdir(parents=True)
            shutil.copyfile(MONITOR / script.name, script)
            package = root / "test/e2e/node_modules/playwright"
            package.mkdir(parents=True)
            (root / "test/e2e/package.json").write_text("{}")
            (package / "index.js").write_text("""
const callbacks = {};
const page = {
  on: (event, callback) => { callbacks[event] = callback; },
  goto: async () => {
    callbacks.console({ type: () => 'error', text: () => 'requestStorageAccess: Permission denied.',
      location: () => ({ url: 'https://example.com/main.dart.js', lineNumber: 2, columnNumber: 3 }) });
    callbacks.requestfinished({
      url: () => 'https://example.com/main.dart.js', resourceType: () => 'script',
      response: async () => ({ ok: () => true, body: async () => Buffer.from('loaded bundle') }),
    });
  },
  title: async () => '',
  locator: () => ({ first: () => ({ waitFor: async () => {} }) }),
  evaluate: async () => [],
  removeAllListeners: () => {},
};
const context = {
  newPage: async () => page,
  request: { get: async () => ({ ok: () => false }) },
};
exports.chromium = { launch: async () => ({ newContext: async () => context, close: async () => {} }) };
""")
            result = subprocess.run([
                "node", str(script), "--url", "https://example.com", "--settle-ms", "0",
            ], cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stderr)
            report = json.loads(result.stdout)
            self.assertFalse(report["ok"])
            self.assertEqual(report["raw_findings"]["console_errors"], [{
                "text": "requestStorageAccess: Permission denied.",
                "location": "https://example.com/main.dart.js:2:3",
            }])

