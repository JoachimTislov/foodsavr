#!/usr/bin/env python3
"""Tests for scripts/setup/monitoring.sh and the single `make monitoring` entry-point."""

from __future__ import annotations

import json
import os
import pty
import re
import select
import stat
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/setup/monitoring.sh"
MAKEFILE = ROOT / "make" / "setup.mk"

AGENT_ENV_KEYS = (
    "CI",
    "GITHUB_ACTIONS",
    "ANTIGRAVITY_AGENT",
    "CLAUDECODE",
    "CLAUDE_AGENT_SDK_VERSION",
    "CODEX_CI",
    "CODEX_THREAD_ID",
    "CODEX_SANDBOX",
    "GEMINI_CLI",
    "OPENCODE",
    "COPILOT_CLI",
    "AGENT_RUNNER",
)


def _human_env(fake_gh: Path) -> dict[str, str]:
    env = {k: v for k, v in os.environ.items() if k not in AGENT_ENV_KEYS}
    env["GH_BIN"] = str(fake_gh)
    env["TERM"] = "xterm-256color"
    return env


def _make_fake_gh(directory: Path, state_file: Path) -> Path:
    gh_path = directory / "gh"
    gh_path.write_text(
        f"""#!/usr/bin/env python3
import json, sys
from pathlib import Path

state_path = Path({str(state_file)!r})
state = json.loads(state_path.read_text())
args = sys.argv[1:]

if args[:2] == ["auth", "status"]:
    sys.exit(0 if state.get("authed", True) else 1)

if args[:2] == ["secret", "list"]:
    for name in state.get("secrets", []):
        print(name)
    sys.exit(0)

if args[:2] == ["variable", "list"]:
    items = [{{"name": k, "value": v}} for k, v in sorted(state.get("variables", {{}}).items())]
    print(json.dumps(items))
    sys.exit(0)

if args[:2] == ["variable", "set"]:
    name = args[2]
    body_idx = args.index("--body")
    value = args[body_idx + 1]
    state.setdefault("variables", {{}})[name] = value
    state_path.write_text(json.dumps(state))
    sys.exit(0)

sys.stderr.write(f"unexpected fake gh args: {{args}}\\n")
sys.exit(1)
""",
        encoding="utf-8",
    )
    gh_path.chmod(gh_path.stat().st_mode | stat.S_IXUSR)
    return gh_path


def _run_in_pty(
    cmd: list[str],
    env: dict[str, str],
    responses: list[tuple[str, str]] | None = None,
    timeout: float = 10.0,
) -> tuple[int, str]:
    master_fd, slave_fd = pty.openpty()
    proc = subprocess.Popen(
        cmd,
        cwd=ROOT,
        env=env,
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        close_fds=True,
    )
    os.close(slave_fd)

    output = bytearray()
    pending = list(responses or [])
    deadline = time.monotonic() + timeout
    try:
        while time.monotonic() < deadline:
            ready, _, _ = select.select([master_fd], [], [], 0.1)
            if ready:
                try:
                    chunk = os.read(master_fd, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                output.extend(chunk)
                decoded = output.decode("utf-8", errors="replace")
                while pending and pending[0][0] in decoded:
                    _, reply = pending.pop(0)
                    os.write(master_fd, reply.encode("utf-8"))
            elif proc.poll() is not None:
                break
        rc = proc.wait(timeout=max(0.1, deadline - time.monotonic()))
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        os.close(master_fd)
    return rc, output.decode("utf-8", errors="replace")


class TestMonitoringEntrypoint(unittest.TestCase):
    def test_script_executable_and_valid_bash(self) -> None:
        self.assertTrue(os.access(SCRIPT, os.X_OK))
        subprocess.run(["bash", "-n", str(SCRIPT)], check=True)

    def test_non_interactive_invocation_is_read_only(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            state_file = tmp / "state.json"
            state_file.write_text(json.dumps({"secrets": [], "variables": {}}))
            fake_gh = _make_fake_gh(tmp, state_file)

            res = subprocess.run(
                [str(SCRIPT)],
                cwd=ROOT,
                env=_human_env(fake_gh),
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(res.returncode, 1)
            self.assertNotIn("Monitoring shell", res.stdout)
            self.assertIn("scripts/human/agents/login-claude-runner.sh", res.stdout)
            self.assertEqual(json.loads(state_file.read_text())["variables"], {})

    def test_non_interactive_passes_when_configured(self) -> None:
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
                [str(SCRIPT)],
                cwd=ROOT,
                env=_human_env(fake_gh),
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
            self.assertIn("Monitoring and healing loop setup checks passed.", res.stdout)
            self.assertNotIn("Monitoring shell", res.stdout)

    def test_agent_and_ci_envs_never_trigger_interactive_shell_even_on_pty(self) -> None:
        for env_key in ("ANTIGRAVITY_AGENT", "CLAUDECODE", "CODEX_CI", "CI"):
            with self.subTest(env_key=env_key), tempfile.TemporaryDirectory() as tmpdir:
                tmp = Path(tmpdir)
                state_file = tmp / "state.json"
                state_file.write_text(json.dumps({"secrets": [], "variables": {}}))
                fake_gh = _make_fake_gh(tmp, state_file)

                env = _human_env(fake_gh)
                env[env_key] = "1"
                rc, out = _run_in_pty([str(SCRIPT)], env=env, responses=[])
                self.assertEqual(rc, 1)
                self.assertNotIn("Monitoring shell", out)
                self.assertEqual(json.loads(state_file.read_text())["variables"], {})

    def test_human_pty_runs_interactive_shell_with_defaults(self) -> None:
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
                        "variables": {},
                    }
                )
            )
            fake_gh = _make_fake_gh(tmp, state_file)

            rc, out = _run_in_pty(
                [str(SCRIPT)],
                env=_human_env(fake_gh),
                responses=[
                    ("Select [1]: ", "\n"),
                    ("FIREBASE_PLAN (spark|blaze) [spark]: ", "\n"),
                    ("AUTO_HEAL_ENABLED (true|false) [true]: ", "\n"),
                    ("AUTO_HEAL_MERGE (true|false) [false]: ", "\n"),
                    ("TELEMETRY_POLL_ENABLED (true|false) [false]: ", "\n"),
                    ("MONITOR_TARGET_URL [https://my-foodsavr-store.web.app]: ", "\n"),
                    ("ERROR_REPORTER (none|spark-firestore|crashlytics-web|external) [none]: ", "\n"),
                    ("Monitoring and healing loop setup checks passed.", "q\n"),
                ],
            )
            self.assertEqual(rc, 0, out)
            self.assertIn("Monitoring shell", out)
            saved = json.loads(state_file.read_text())["variables"]
            self.assertEqual(saved["FIREBASE_PLAN"], "spark")
            self.assertEqual(saved["AUTO_HEAL_ENABLED"], "true")
            self.assertEqual(saved["AUTO_HEAL_MERGE"], "false")
            self.assertEqual(saved["TELEMETRY_POLL_ENABLED"], "false")
            self.assertEqual(saved["MONITOR_TARGET_URL"], "https://my-foodsavr-store.web.app")
            self.assertEqual(saved["ERROR_REPORTER"], "none")

    def test_makefile_has_single_monitoring_target(self) -> None:
        content = MAKEFILE.read_text(encoding="utf-8")
        monitoring_targets = re.findall(r"^(monitoring[a-z0-9_-]*):", content, flags=re.MULTILINE)
        self.assertEqual(monitoring_targets, ["monitoring"])

        res = subprocess.run(
            ["make", "-n", "monitoring"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual(res.stdout.strip(), "scripts/setup/monitoring.sh")


if __name__ == "__main__":
    unittest.main()
