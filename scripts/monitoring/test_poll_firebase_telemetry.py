#!/usr/bin/env python3
"""Unit tests for poll_firebase_telemetry Spark and Blaze adapters."""

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.monitoring.poll_firebase_telemetry import (  # noqa: E402
    poll_blaze_cloud_logging,
    poll_spark_firestore,
    resolve_plan,
)


class PollFirebaseTelemetryTest(unittest.TestCase):
    def test_resolve_plan_respects_explicit_level_and_manifest(self):
        self.assertEqual(resolve_plan("blaze"), "blaze")
        self.assertEqual(resolve_plan("auto", deployment_level="firebase-blaze"), "blaze")
        with tempfile.TemporaryDirectory() as tmp:
            manifest = Path(tmp) / "instance.yaml"
            manifest.write_text(
                "environments:\n  production:\n    currentLevel: firebase-spark\n",
                encoding="utf-8",
            )
            self.assertEqual(resolve_plan("auto", instance_yaml=manifest), "spark")

    def test_poll_spark_firestore_normalizes_run_query_documents(self):
        captured = {}

        def fake_post(url, payload, headers):
            captured["url"] = url
            captured["payload"] = payload
            captured["headers"] = headers
            return [
                {
                    "document": {
                        "name": "projects/example-project/databases/(default)/documents/runtime_errors/1",
                        "createTime": "2026-11-22T01:00:00Z",
                        "fields": {
                            "error_type": {"stringValue": "EmptyEnvFileError"},
                            "message": {"stringValue": 'Environment file "assets/.env" is empty.'},
                            "platform": {"stringValue": "web"},
                        },
                    }
                },
                {"readTime": "2026-11-22T01:00:01Z"},
            ]

        events = poll_spark_firestore(
            project_id="example-project",
            access_token="tok-123",
            http_post=fake_post,
        )
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].source, "firebase/spark-firestore")
        self.assertEqual(events[0].error_type, "EmptyEnvFileError")
        self.assertIn("runtime_errors", str(captured["payload"]))
        self.assertEqual(captured["headers"]["Authorization"], "Bearer tok-123")

    def test_poll_blaze_cloud_logging_normalizes_entries(self):
        def fake_post(url, payload, headers):
            self.assertIn("logging.googleapis.com", url)
            self.assertIn("firebase-telemetry", payload["filter"])
            return {
                "entries": [
                    {
                        "logName": "projects/example-project/logs/firebase-telemetry",
                        "timestamp": "2026-11-22T01:05:00Z",
                        "severity": "ERROR",
                        "jsonPayload": {
                            "name": "StateError",
                            "message": "Bad state on web",
                            "platform": "web",
                        },
                    }
                ]
            }

        events = poll_blaze_cloud_logging(
            project_id="example-project",
            access_token="tok-456",
            http_post=fake_post,
        )
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0].source, "firebase/crashlytics-web")
        self.assertEqual(events[0].deployment_level, "firebase-blaze")


if __name__ == "__main__":
    unittest.main()
