#!/usr/bin/env python3
"""Tests for scripts/secrets/rotate.py."""

from __future__ import annotations

import importlib.util
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock

spec = importlib.util.spec_from_file_location("rotate", Path(__file__).with_name("rotate.py"))
rotate = importlib.util.module_from_spec(spec)
sys.modules["rotate"] = rotate
spec.loader.exec_module(rotate)


def registry_from(text: str):
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp, "r.toml")
        path.write_text(text)
        return rotate.load_registry(path)


class RegistryTest(unittest.TestCase):
    def test_checked_in_registry_is_valid(self):
        registry = rotate.load_registry()
        self.assertIn("FIREBASE_OPTIONS_B64", registry)
        self.assertTrue(registry["FACEBOOK_CLIENT_TOKEN"].public)
        self.assertFalse(registry["FACEBOOK_APP_SECRET"].public)

    def test_invalid_entries_raise_value_error(self):
        for text in (
            '[secrets.X]\ngenerate = "nope"\n',
            "[secrets.X]\nunknown_key = 1\n",
            '[secrets.X]\ngroups = "ci"\n',
            '[secrets.X]\npublic = "false"\n',
            "[secrets.X]\nlength = true\n",
            '[secrets.lower]\ngenerate = "manual"\n',
            "[secrets.X\n",
        ):
            with self.subTest(text=text), self.assertRaises(ValueError):
                registry_from(text)


class SelectTest(unittest.TestCase):
    registry = {
        "CHEAP": rotate.Secret("CHEAP", generate="random", effort="low"),
        "COSTLY": rotate.Secret("COSTLY"),
    }

    def test_low_effort_skips_high_effort(self):
        names = [s.name for s in rotate.select(self.registry, [], True, [])]
        self.assertEqual(names, ["CHEAP"])

    def test_named_high_effort_is_included_once(self):
        names = [s.name for s in rotate.select(self.registry, ["COSTLY", "CHEAP"], True, [])]
        self.assertEqual(names, ["CHEAP", "COSTLY"])

    def test_unknown_name_needs_sink(self):
        with self.assertRaises(ValueError):
            rotate.select(self.registry, ["COSTLI"], False, [])
        (secret,) = rotate.select(self.registry, ["ANY_SECRET"], False, ["env"])
        self.assertEqual((secret.generate, secret.sinks), ("manual", ["env"]))

    def test_invalid_name_is_rejected(self):
        with self.assertRaises(ValueError):
            rotate.select(self.registry, ["lower-case!"], False, ["env"])

    def test_sink_with_registered_name_is_rejected(self):
        with self.assertRaises(ValueError):
            rotate.select(self.registry, ["COSTLY"], False, ["env"])


class GroupTest(unittest.TestCase):
    registry = {
        "A": rotate.Secret("A", generate="random", effort="low", groups=["g"]),
        "B": rotate.Secret("B", groups=["g", "h"]),
        "C": rotate.Secret("C", groups=["h"]),
    }

    def test_group_skips_public_unless_named(self):
        registry = {**self.registry, "P": rotate.Secret("P", public=True, groups=["g"])}
        grouped = [s.name for s in rotate.select(registry, ["@g"], False, [])]
        self.assertNotIn("P", grouped)
        named = [s.name for s in rotate.select(registry, ["@g", "P"], False, [])]
        self.assertIn("P", named)

    def test_public_only_group_explains(self):
        registry = {"P": rotate.Secret("P", public=True, groups=["pub"])}
        with self.assertRaisesRegex(ValueError, "only public"):
            rotate.select(registry, ["@pub"], False, [])

    def test_group_includes_high_effort_members(self):
        names = [s.name for s in rotate.select(self.registry, [], False, [], ["g"])]
        self.assertEqual(names, ["A", "B"])

    def test_at_shorthand_and_overlapping_groups_dedupe(self):
        names = [s.name for s in rotate.select(self.registry, ["@g", "@h", "B"], False, [])]
        self.assertEqual(names, ["A", "B", "C"])

    def test_unknown_group_fails(self):
        with self.assertRaises(ValueError):
            rotate.select(self.registry, ["@nope"], False, [])

    def test_checked_in_groups(self):
        registry = rotate.load_registry()
        groups = rotate.group_names(registry)
        self.assertIn("FIREBASE_CLI_TOKEN", groups["firebase"])
        leaked = [s.name for s in rotate.select(registry, ["@meta"], False, [])]
        self.assertEqual(leaked, ["FACEBOOK_APP_SECRET"])


class GenerateTest(unittest.TestCase):
    def test_random_respects_length_and_alphabet(self):
        value = rotate.generate(rotate.Secret("R", generate="random", length=40, alphabet="hex"))
        self.assertEqual(len(value), 40)
        self.assertTrue(set(value) <= set("0123456789abcdef"))

    def test_manual_prefers_env_then_prompt(self):
        secret = rotate.Secret("M")
        self.assertEqual(rotate.generate(secret, env={"NEW_M": "v1"}), "v1")
        self.assertEqual(rotate.generate(secret, env={}, prompt=lambda _: "v2", interactive=True), "v2")

    def test_manual_without_tty_fails_instead_of_prompting(self):
        prompt = MagicMock()
        with self.assertRaisesRegex(ValueError, "NEW_M"):
            rotate.generate(rotate.Secret("M"), env={}, prompt=prompt, interactive=False)
        prompt.assert_not_called()

    def test_empty_value_fails(self):
        with self.assertRaises(ValueError):
            rotate.generate(rotate.Secret("M"), env={}, prompt=lambda _: "", interactive=True)


class PushTest(unittest.TestCase):
    def test_env_sink_quotes_replaces_export_and_sets_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = Path(tmp, ".env")
            env.write_text("A=1\nexport KEY=old\n")
            env.chmod(0o644)
            rotate.push(rotate.Secret("KEY", sinks=["env"]), "a b#c=d", env_path=env)
            self.assertEqual(env.read_text(), "A=1\nKEY='a b#c=d'\n")
            self.assertEqual(stat.S_IMODE(os.stat(env).st_mode), 0o600)

    def test_env_sink_rejects_unquotable_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            for value in ("it's", "a\rb", "a\nb"):
                with self.subTest(value=value), self.assertRaises(rotate.PushError):
                    rotate.push(rotate.Secret("KEY", sinks=["env"]), value, env_path=Path(tmp, ".env"))

    def test_github_sink_sends_value_on_stdin_and_passes_repo(self):
        run = MagicMock()
        rotate.push(rotate.Secret("KEY"), "v", env_path=Path("/nonexistent"), run=run)
        run.assert_called_once_with(["gh", "secret", "set", "KEY"], input="v", text=True, check=True)
        run.reset_mock()
        rotate.push(rotate.Secret("KEY"), "v", env_path=Path("/nonexistent"), repo="alice/foodsavr", run=run)
        run.assert_called_once_with(["gh", "secret", "set", "KEY", "--repo", "alice/foodsavr"], input="v", text=True, check=True)

    def test_sync_file_encodes_base64_without_shell(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            target = home / "secret.txt"
            target.write_bytes(b"hello\nworld")
            secret = rotate.Secret("S", generate="sync", sync_file="~/secret.txt", encode="base64")
            self.assertEqual(rotate.generate(secret, env={"HOME": str(home)}), "aGVsbG8Kd29ybGQ=")

    def test_github_mutation_guard_blocks_agent_env_and_cross_repo_without_tty(self):
        err_agent = rotate.check_github_mutation_guard(
            "alice/foodsavr", env={"AGENT_SESSION_ID": "test:1"}, interactive=False, origin_slug="alice/foodsavr",
        )
        self.assertIsNotNone(err_agent)
        err_cross = rotate.check_github_mutation_guard(
            "upstream/foodsavr", env={}, interactive=False, origin_slug="alice/foodsavr",
        )
        self.assertIsNotNone(err_cross)
        self.assertIsNone(
            rotate.check_github_mutation_guard(
                "upstream/foodsavr", env={}, interactive=False, origin_slug="alice/foodsavr", yes=True,
            )
        )

    def test_partial_failure_reports_updated_sinks(self):
        with tempfile.TemporaryDirectory() as tmp:
            run = MagicMock(side_effect=subprocess.CalledProcessError(1, "gh"))
            secret = rotate.Secret("KEY", sinks=["env", "github"])
            with self.assertRaises(rotate.PushError) as caught:
                rotate.push(secret, "v", env_path=Path(tmp, ".env"), run=run)
            self.assertEqual((caught.exception.done, caught.exception.sink), (["env"], "github"))
            self.assertNotIn("'v'", str(caught.exception))


class MainTest(unittest.TestCase):
    def test_sync_is_reported_as_dry_run_sync(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp, "r.toml")
            path.write_text('[secrets.S]\ngenerate = "sync"\nsync_file = "README.md"\nencode = "base64"\neffort = "low"\n')
            out = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("rotate.py")), "--registry", str(path),
                 "--repo", "alice/foodsavr", "--low-effort", "--dry-run"],
                capture_output=True, text=True, check=True,
            ).stdout
            self.assertIn("would sync S", out)
            self.assertIn("[alice/foodsavr]", out)

    def test_only_sink_filters_registered_sinks_and_rejects_unconfigured_sink(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp, "r.toml")
            env_path = Path(tmp, ".env")
            path.write_text('[secrets.ROUTER_MODEL]\npublic = true\nsinks = ["env", "github"]\n')
            proc = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("rotate.py")), "--registry", str(path),
                 "--env-file", str(env_path), "--only-sink", "env", "ROUTER_MODEL"],
                env={**os.environ, "NEW_ROUTER_MODEL": "gpt-6.2-sol"},
                capture_output=True, text=True, check=True,
            )
            self.assertIn("rotated ROUTER_MODEL (manual -> env)", proc.stdout)
            self.assertEqual(env_path.read_text(), "ROUTER_MODEL='gpt-6.2-sol'\n")
            bad = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("rotate.py")), "--registry", str(path),
                 "--only-sink", "github", "--registry", str(path)],
                capture_output=True, text=True,
            )
            self.assertNotEqual(bad.returncode, 0)
            path.write_text('[secrets.LOCAL_ONLY]\nsinks = ["env"]\n')
            rejected = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("rotate.py")), "--registry", str(path),
                 "--only-sink", "github", "LOCAL_ONLY"],
                capture_output=True, text=True,
            )
            self.assertNotEqual(rejected.returncode, 0)


if __name__ == "__main__":
    unittest.main()
