#!/usr/bin/env python3
"""Tests for scripts/secrets/rotate.py."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock

spec = importlib.util.spec_from_file_location("rotate", Path(__file__).with_name("rotate.py"))
rotate = importlib.util.module_from_spec(spec)
sys.modules["rotate"] = rotate
spec.loader.exec_module(rotate)


class RegistryTest(unittest.TestCase):
    def test_checked_in_registry_is_valid(self):
        registry = rotate.load_registry()
        self.assertIn("FIREBASE_OPTIONS_B64", registry)

    def test_invalid_entry_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp, "r.toml")
            path.write_text('[secrets.X]\ngenerate = "nope"\n')
            with self.assertRaises(ValueError):
                rotate.load_registry(path)


class SelectTest(unittest.TestCase):
    registry = {
        "CHEAP": rotate.Secret("CHEAP", generate="random", cost="cheap"),
        "COSTLY": rotate.Secret("COSTLY"),
    }

    def test_cheap_skips_expensive(self):
        names = [s.name for s in rotate.select(self.registry, [], True, [])]
        self.assertEqual(names, ["CHEAP"])

    def test_named_expensive_is_included_once(self):
        names = [s.name for s in rotate.select(self.registry, ["COSTLY", "CHEAP"], True, [])]
        self.assertEqual(names, ["CHEAP", "COSTLY"])

    def test_unknown_name_is_manual_with_given_sinks(self):
        (secret,) = rotate.select(self.registry, ["ANY_SECRET"], False, ["env"])
        self.assertEqual((secret.generate, secret.sinks), ("manual", ["env"]))


class GroupTest(unittest.TestCase):
    registry = {
        "A": rotate.Secret("A", generate="random", cost="cheap", groups=["g"]),
        "B": rotate.Secret("B", groups=["g", "h"]),
        "C": rotate.Secret("C", groups=["h"]),
    }

    def test_group_includes_expensive_members(self):
        names = [s.name for s in rotate.select(self.registry, [], False, [], ["g"])]
        self.assertEqual(names, ["A", "B"])

    def test_at_shorthand_and_overlapping_groups_dedupe(self):
        names = [s.name for s in rotate.select(self.registry, ["@g", "@h", "B"], False, [])]
        self.assertEqual(names, ["A", "B", "C"])

    def test_unknown_group_fails(self):
        with self.assertRaises(ValueError):
            rotate.select(self.registry, ["@nope"], False, [])

    def test_checked_in_groups_exist(self):
        groups = rotate.group_names(rotate.load_registry())
        self.assertIn("FIREBASE_CLI_TOKEN", groups["firebase"])


class GenerateTest(unittest.TestCase):
    def test_random_respects_length_and_alphabet(self):
        value = rotate.generate(rotate.Secret("R", generate="random", length=40, alphabet="hex"))
        self.assertEqual(len(value), 40)
        self.assertTrue(set(value) <= set("0123456789abcdef"))

    def test_manual_prefers_env_then_prompt(self):
        secret = rotate.Secret("M")
        self.assertEqual(rotate.generate(secret, env={"NEW_M": "v1"}), "v1")
        self.assertEqual(rotate.generate(secret, env={}, prompt=lambda _: "v2"), "v2")

    def test_empty_value_fails(self):
        with self.assertRaises(ValueError):
            rotate.generate(rotate.Secret("M"), env={}, prompt=lambda _: "")


class PushTest(unittest.TestCase):
    def test_env_sink_replaces_existing_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = Path(tmp, ".env")
            env.write_text("A=1\nKEY=old\n")
            rotate.push(rotate.Secret("KEY", sinks=["env"]), "new", env_path=env)
            self.assertEqual(env.read_text(), "A=1\nKEY=new\n")

    def test_github_sink_sends_value_on_stdin(self):
        run = MagicMock()
        rotate.push(rotate.Secret("KEY"), "v", env_path=Path("/nonexistent"), run=run)
        run.assert_called_once_with(["gh", "secret", "set", "KEY"], input="v", text=True, check=True)


if __name__ == "__main__":
    unittest.main()
