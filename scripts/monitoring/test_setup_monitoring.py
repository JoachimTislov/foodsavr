#!/usr/bin/env python3
"""Tests for scripts/setup/monitoring.sh and its Makefile entry-points."""

from __future__ import annotations

import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/setup/monitoring.sh"


def _make_fake_gh(directory: Path, state_file: Path) -> Path:
    gh_path = directory / "gh"
    gh_path.write_text(
        f"""#!/usr/bin/env python3
import json, sys
from pathlib import Path

state_path = Path({str(state_file)!r})
state = json.loads(state_path.read_text())
args = sys.argv[1:]

# Strip optional -R <repo>
cleaned = []
i = 0
while i < len(args):
    if args[i] == "-R" and i + 1 < len(args):
        i += 2
        continue
    cleaned.append(args[i])
    i += 1

if cleaned[:2] == ["auth", "status"]:
    sys.exit(0 if state.get("authed", True) else 1)

if cleaned[:2] == ["secret", "list"]:
    for name in state.get("secrets", []):
        print(name)
    sys.exit(0)

if cleaned[:2] == ["variable", "list"]:
    items = [{{"name": k, "value": v}} for k, v in sorted(state.get("variables", {{}}).items())]
    print(json.dumps(items))
    sys.exit(0)

if cleaned[:2] == ["variable", "set"]:
    name = cleaned[2]
    body_idx = cleaned.index("--body")
    value = cleaned[body_idx + 1]
    state.setdefault("variables", {{}})[name] = value
    state_path.write_text(json.dumps(state))
    sys.exit(0)

sys.stderr.write(f"unexpected fake gh args: {{cleaned}}\\n")
sys.exit(1)
""",
        encoding="utf-8",
    )
    gh_path.chmod(gh_path.stat().st_mode | stat.S_IXUSR)
    return gh_path


class TestMonitoringSetupScript(unittest.TestCase):
    def test_script_executable_and_valid_bash(self) -> None:
        self.assertTrue(os.access(SCRIPT, os.X_OK))
        subprocess.run(["bash", "-n", str(SCRIPT)], check=True)

    def test_check_mode_reports_missing_secrets_and_auto_heal(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            state_file = tmp / "state.json"
            state_file.write_text(json.dumps({"secrets": [], "variables": {}}))
            fake_gh = _make_fake_gh(tmp, state_file)

            res = subprocess.run(
                [str(SCRIPT), "--check"],
                cwd=ROOT,
                env={**os.environ, "GH_BIN": str(fake_gh)},
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 1)
            self.assertIn("scripts/human/agents/login-claude-runner.sh", res.stdout)
            self.assertIn("scripts/human/github/create-agent-app.sh", res.stdout)
            self.assertIn("AUTO_HEAL_ENABLED", res.stdout)

    def test_check_mode_passes_when_required_state_present(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            state_file = tmp / "state.json"
            state_file.write_text(
                json.dumps(
                    {
                        "secrets": [
                            "CLAUDE_CODE_OAUTH_TOKEN",
                            "AGENT_APP_ID",
                            "AGENT_APP_PRIVATE_KEY",
                        ],
                        "variables": {
                            "FIREBASE_PLAN": "spark",
                            "AUTO_HEAL_ENABLED": "true",
                        },
                    }
                )
            )
            fake_gh = _make_fake_gh(tmp, state_file)

            res = subprocess.run(
                [str(SCRIPT), "--check"],
                cwd=ROOT,
                env={**os.environ, "GH_BIN": str(fake_gh)},
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
            self.assertIn("Monitoring and healing loop setup checks passed.", res.stdout)

    def test_non_interactive_flags_configure_variables(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            state_file = tmp / "state.json"
            state_file.write_text(
                json.dumps(
                    {
                        "secrets": [
                            "CODEX_AUTH_JSON_B64",
                            "AGENT_APP_ID",
                            "AGENT_APP_PRIVATE_KEY",
                        ],
                        "variables": {},
                    }
                )
            )
            fake_gh = _make_fake_gh(tmp, state_file)

            res = subprocess.run(
                [
                    str(SCRIPT),
                    "--no-interactive",
                    "--plan",
                    "spark",
                    "--auto-heal",
                    "true",
                    "--auto-heal-merge",
                    "false",
                    "--telemetry-poll",
                    "false",
                    "--target-url",
                    "https://my-foodsavr-store.web.app",
                    "--error-reporter",
                    "none",
                ],
                cwd=ROOT,
                env={**os.environ, "GH_BIN": str(fake_gh)},
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
            saved = json.loads(state_file.read_text())["variables"]
            self.assertEqual(saved["FIREBASE_PLAN"], "spark")
            self.assertEqual(saved["AUTO_HEAL_ENABLED"], "true")
            self.assertEqual(saved["AUTO_HEAL_MERGE"], "false")
            self.assertEqual(saved["TELEMETRY_POLL_ENABLED"], "false")
            self.assertEqual(saved["MONITOR_TARGET_URL"], "https://my-foodsavr-store.web.app")
            self.assertEqual(saved["ERROR_REPORTER"], "none")

    def test_invalid_flags_fail_fast(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            state_file = tmp / "state.json"
            state_file.write_text(json.dumps({"secrets": [], "variables": {}}))
            fake_gh = _make_fake_gh(tmp, state_file)

            bad_plan = subprocess.run(
                [str(SCRIPT), "--plan", "enterprise", "--no-interactive"],
                cwd=ROOT,
                env={**os.environ, "GH_BIN": str(fake_gh)},
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
            )
            self.assertEqual(bad_plan.returncode, 2)

            bad_url = subprocess.run(
                [str(SCRIPT), "--target-url", "http://insecure.example", "--no-interactive"],
                cwd=ROOT,
                env={**os.environ, "GH_BIN": str(fake_gh)},
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
            )
            self.assertEqual(bad_url.returncode, 2)

            missing_endpoint = subprocess.run(
                [str(SCRIPT), "--error-reporter", "external", "--no-interactive"],
                cwd=ROOT,
                env={**os.environ, "GH_BIN": str(fake_gh)},
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
            )
            self.assertEqual(missing_endpoint.returncode, 2)
            self.assertEqual(json.loads(state_file.read_text())["variables"], {})

    def test_makefile_targets_resolve(self) -> None:
        for target, expected in [
            ("monitoring-setup", "scripts/setup/monitoring.sh"),
            ("monitoring-check", "scripts/setup/monitoring.sh --check"),
            ("monitoring-probe", "scripts/monitoring/probe_web.mjs"),
            ("monitoring-test", "unittest discover -s scripts/monitoring"),
        ]:
            res = subprocess.run(
                ["make", "-n", target],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertIn(expected, res.stdout)


if __name__ == "__main__":
    unittest.main()
