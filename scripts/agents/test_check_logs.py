#!/usr/bin/env python3
"""Regression coverage for repository log format enforcement."""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("check_logs", Path(__file__).with_name("check_logs.py"))
logs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(logs)


class LogFormatTests(unittest.TestCase):
    def test_accepts_objects_with_escaped_multiline_text(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "ledger.jsonl"
            path.write_text(json.dumps({"event": "first\nsecond | café"}) + "\n{}\n", encoding="utf-8")
            logs.validate(path)
            path.write_text("")
            logs.validate(path)

    def test_rejects_invalid_records_with_location(self):
        for record in ('\n', '[]\n', 'null\n', '{}\nnot json\n', '{"count":NaN}\n', '{"count":Infinity}\n', '\ufeff{}\n'):
            with self.subTest(record=record), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "events.jsonl"
                path.write_text(record, encoding="utf-8")
                with self.assertRaisesRegex(ValueError, 'events.jsonl:[12]:'):
                    logs.validate(path)

    def test_requires_final_newline(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "index.jsonl"
            path.write_text('{}')
            with self.assertRaisesRegex(ValueError, 'missing final newline'):
                logs.validate(path)

    def test_checks_all_jsonl_and_rejects_legacy_logs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'new.jsonl').write_text('false\n')
            errors = logs.check(root, [
                'new.jsonl', '.agents/ledger.md', 'log/new.log',
                'elsewhere/new.log', '.agents/sessions/index.md', '.agents/reviews/history.md',
            ])
            self.assertEqual(len(errors), 6)
            self.assertIn('record must be an object', errors[0])
            self.assertIn('must use .jsonl', errors[1])
            self.assertIn('must use .jsonl', errors[2])
            self.assertIn('must use .jsonl', errors[5])
            self.assertEqual(logs.check(root, ['docs/README.md']), [])


if __name__ == '__main__':
    unittest.main()
