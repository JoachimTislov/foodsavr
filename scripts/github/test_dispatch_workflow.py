#!/usr/bin/env python3
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dispatch_workflow as dw  # noqa: E402


class DispatchTest(unittest.TestCase):
    def test_detects_workflow_dispatch(self):
        self.assertTrue(dw.has_dispatch("on:\n  push:\n  workflow_dispatch:\n    inputs:\n"))
        self.assertFalse(dw.has_dispatch("on:\n  push:\n    branches: [x]\n"))
        self.assertFalse(dw.has_dispatch("# workflow_dispatch is not used\non: push\n"))

    def test_resolve_accepts_name_with_or_without_extension(self):
        self.assertEqual(dw.resolve("validation").name, "validation.yml")
        self.assertEqual(dw.resolve("validation.yml").name, "validation.yml")

    def test_resolve_refuses_workflow_without_dispatch(self):
        with self.assertRaises(SystemExit) as raised:
            dw.resolve("release-gated")
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
