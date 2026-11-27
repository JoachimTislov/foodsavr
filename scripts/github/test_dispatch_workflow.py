#!/usr/bin/env python3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dispatch_workflow as dw  # noqa: E402


class DispatchTest(unittest.TestCase):
    def test_detects_workflow_dispatch(self):
        self.assertTrue(dw.has_dispatch("on:\n  push:\n  workflow_dispatch:\n    inputs:\n"))
        self.assertFalse(dw.has_dispatch("on:\n  push:\n    branches: [x]\n"))
        self.assertFalse(dw.has_dispatch("# workflow_dispatch is not used\non: push\n"))

    def test_resolve_accepts_name_with_or_without_extension(self):
        self.assertEqual(dw.resolve("pull-request").name, "pull-request.yml")
        self.assertEqual(dw.resolve("pull-request.yml").name, "pull-request.yml")

    def test_every_consolidated_workflow_is_dispatchable(self):
        for name in ("pull-request", "merge-gate", "release", "agent-ops", "ops-maintenance", "manual-tools"):
            with self.subTest(name=name):
                self.assertEqual(dw.resolve(name).name, f"{name}.yml")

    def test_resolve_refuses_workflow_without_dispatch(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(dw, "WORKFLOWS", Path(tmp)):
            (Path(tmp) / "events-only.yml").write_text("on:\n  push:\n    branches: [x]\n")
            with self.assertRaises(SystemExit) as raised:
                dw.resolve("events-only")
        self.assertIn("no workflow_dispatch", str(raised.exception))

    def test_resolve_refuses_unknown_workflow(self):
        with self.assertRaises(SystemExit) as raised:
            dw.resolve("nope")
        self.assertIn("dispatchable", str(raised.exception))

    def test_inputs_must_be_key_value(self):
        self.assertEqual(dw.parse_inputs(["a=b"]), ["a=b"])
        with self.assertRaises(SystemExit):
            dw.parse_inputs(["novalue"])


if __name__ == "__main__":
    unittest.main()
