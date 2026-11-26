#!/usr/bin/env python3
"""Pull poller for Firebase Spark (Firestore runtime_errors) and Blaze (Cloud Logging firebase-telemetry)."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.monitoring.fault_schema import FaultEvent, normalize_payload  # noqa: E402

HttpPost = Callable[[str, dict[str, Any], dict[str, str]], dict[str, Any]]


def default_http_post(url: str, payload: dict[str, Any], headers: dict[str, str]) -> dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json", **headers},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def default_http_post_list(url: str, payload: dict[str, Any], headers: dict[str, str]) -> list[dict[str, Any]]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json", **headers},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        parsed = json.loads(resp.read().decode("utf-8"))
        return parsed if isinstance(parsed, list) else [parsed]


def resolve_access_token() -> str:
    for env_var in ("ACCESS_TOKEN", "GOOGLE_OAUTH_ACCESS_TOKEN"):
        token = os.environ.get(env_var, "").strip()
        if token:
            return token

    try:
        import google.auth  # type: ignore[import-not-found]
        import google.auth.transport.requests  # type: ignore[import-not-found]

        creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
        creds.refresh(google.auth.transport.requests.Request())
        if creds.token:
            return str(creds.token)
    except Exception:
        pass

    if shutil.which("gcloud"):
        out = subprocess.check_output(["gcloud", "auth", "print-access-token"], text=True).strip()
        if out:
            return out

    raise RuntimeError(
        "No GCP access token available; configure google-github-actions/auth@v3 (token_format: access_token) or ADC."
    )


def resolve_plan(
    plan: str = "auto",
    *,
    deployment_level: str | None = None,
    instance_yaml: Path = ROOT / "deploy/instance.yaml",
) -> str:
    if plan in {"spark", "blaze"}:
        return plan
    level = (deployment_level or os.environ.get("DEPLOYMENT_LEVEL") or "").strip().lower()
    if level == "firebase-blaze":
        return "blaze"
    if level == "firebase-spark":
        return "spark"
    env_plan = os.environ.get("FIREBASE_PLAN", "").strip().lower()
    if env_plan in {"spark", "blaze"}:
        return env_plan
    if instance_yaml.exists():
        text = instance_yaml.read_text(encoding="utf-8")
        match = re.search(r"production:\s*(?:\n\s+.*)*?\n\s+currentLevel:\s*(\S+)", text)
        if match:
            found = match.group(1).strip().lower()
            if "blaze" in found:
                return "blaze"
            if "spark" in found:
                return "spark"
    return "spark"


def poll_spark_firestore(
    *,
    project_id: str,
    access_token: str,
    limit: int = 25,
    environment: str = "production",
    http_post: Callable[[str, dict[str, Any], dict[str, str]], Any] = default_http_post_list,
) -> list[FaultEvent]:
    url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents:runQuery"
    query = {
        "structuredQuery": {
            "from": [{"collectionId": "runtime_errors"}],
            "where": {
                "fieldFilter": {
                    "field": {"fieldPath": "status"},
                    "op": "EQUAL",
                    "value": {"stringValue": "new"},
                }
            },
            "limit": limit,
        }
    }
    rows = http_post(url, query, {"Authorization": f"Bearer {access_token}"})
    if isinstance(rows, dict):
        rows = [rows]
    events: list[FaultEvent] = []
    for row in rows:
        if isinstance(row, dict) and "document" in row:
            events.extend(
                normalize_payload(
                    row,
                    default_source="firebase/spark-firestore",
                    default_environment=environment,
                    default_deployment_level="firebase-spark",
                )
            )
    return events


def poll_blaze_cloud_logging(
    *,
    project_id: str,
    access_token: str,
    since_minutes: int = 360,
    limit: int = 25,
    environment: str = "production",
    http_post: HttpPost = default_http_post,
) -> list[FaultEvent]:
    url = "https://logging.googleapis.com/v2/entries:list"
    since_ts = (
        (datetime.now(timezone.utc) - timedelta(minutes=since_minutes))
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )
    body = {
        "resourceNames": [f"projects/{project_id}"],
        "filter": f'logName:"firebase-telemetry" AND severity>=ERROR AND timestamp>="{since_ts}"',
        "orderBy": "timestamp desc",
        "pageSize": limit,
    }
    resp = http_post(url, body, {"Authorization": f"Bearer {access_token}"})
    events: list[FaultEvent] = []
    for entry in resp.get("entries", []) or []:
        events.extend(
            normalize_payload(
                entry,
                default_source="firebase/crashlytics-web",
                default_environment=environment,
                default_deployment_level="firebase-blaze",
            )
        )
    return events


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", choices=["auto", "spark", "blaze"], default="auto")
    parser.add_argument("--project", default=os.environ.get("FIREBASE_PROJECT_ID", ""),
                        help="Firebase project (default: FIREBASE_PROJECT_ID)")
    parser.add_argument("--environment", default="production")
    parser.add_argument("--deployment-level", default="")
    parser.add_argument("--since-minutes", type=int, default=360)
    parser.add_argument("--limit", type=int, default=25)
    parser.add_argument("--out", default=None, help="Optional output file path")
    args = parser.parse_args(argv)
    if not args.project:
        parser.error("no Firebase project: pass --project or set FIREBASE_PROJECT_ID")

    selected_plan = resolve_plan(args.plan, deployment_level=args.deployment_level)
    token = resolve_access_token()

    if selected_plan == "blaze":
        events = poll_blaze_cloud_logging(
            project_id=args.project,
            access_token=token,
            since_minutes=args.since_minutes,
            limit=args.limit,
            environment=args.environment,
        )
    else:
        events = poll_spark_firestore(
            project_id=args.project,
            access_token=token,
            limit=args.limit,
            environment=args.environment,
        )

    payload = {
        "plan": selected_plan,
        "project": args.project,
        "count": len(events),
        "events": [e.to_dict() for e in events],
    }
    rendered = json.dumps(payload, indent=2)
    if args.out:
        Path(args.out).write_text(rendered + "\n", encoding="utf-8")
    else:
        print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
