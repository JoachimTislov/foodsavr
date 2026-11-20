#!/usr/bin/env python3
"""Restore release inputs without putting secrets in shell commands or logs."""

import base64
import json
import os
from pathlib import Path


def prepare():
    required = (
        "ANDROID_KEYSTORE_B64", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS",
        "ANDROID_KEY_PASSWORD", "ANDROID_FIREBASE_OPTIONS_B64",
        "ANDROID_GOOGLE_SERVICES_B64", "ANDROID_ENV_B64",
    )
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise ValueError("Missing GitHub secrets: " + ", ".join(missing))

    files = {
        "ANDROID_KEYSTORE_B64": Path(os.environ["RUNNER_TEMP"]) / "android-upload.jks",
        "ANDROID_FIREBASE_OPTIONS_B64": Path("lib/firebase_options.dart"),
        "ANDROID_GOOGLE_SERVICES_B64": Path("android/app/src/production/google-services.json"),
        "ANDROID_ENV_B64": Path("assets/.env"),
    }
    decoded = {name: base64.b64decode(os.environ[name], validate=True) for name in files}
    if any(not value.strip() for value in decoded.values()):
        raise ValueError("Release inputs must not be empty")
    google = json.loads(decoded["ANDROID_GOOGLE_SERVICES_B64"])
    packages = {
        client["client_info"]["android_client_info"]["package_name"]
        for client in google.get("client", [])
    }
    if "com.foodsavr.app" not in packages:
        raise ValueError("ANDROID_GOOGLE_SERVICES_B64 must configure com.foodsavr.app")
    if google.get("project_info", {}).get("project_id", "").startswith("demo-"):
        raise ValueError("A downloadable release requires a real Firebase project")
    for name, path in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(decoded[name])
        path.chmod(0o600)
    with open(os.environ["GITHUB_ENV"], "a") as output:
        output.write(f"ANDROID_KEYSTORE_PATH={files['ANDROID_KEYSTORE_B64']}\n")


if __name__ == "__main__":
    try:
        prepare()
    except (ValueError, KeyError, OSError) as error:
        # Decoder errors never include credential values; don't dump parsed JSON.
        if isinstance(error, ValueError) and not isinstance(error, json.JSONDecodeError):
            print(f"::error::{error}")
        else:
            print("::error::Invalid or unreadable Android release configuration")
        raise SystemExit(1)
