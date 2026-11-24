#!/usr/bin/env python3
"""Write web-only Firebase options and firebase.json for Hosting.

stdin: `firebase apps:sdkconfig WEB <appId> --json` output.
env:   DEPLOY_ENVIRONMENT (default test): `production` writes
       lib/firebase_options_prod.dart, anything else lib/firebase_options.dart
       (the file lib/main.dart selects for that environment);
       PROJECT_ID (optional): the config must belong to this project;
       SITE_ID (optional, defaults to the projectId): Hosting site;
       ANDROID_APK_URL (optional) -> /android redirect.
"""

import json
import os
import sys

FIELDS = {  # FirebaseOptions name -> sdkconfig key
    "apiKey": "apiKey",
    "appId": "appId",
    "messagingSenderId": "messagingSenderId",
    "projectId": "projectId",
    "authDomain": "authDomain",
    "storageBucket": "storageBucket",
    "measurementId": "measurementId",
}

# Deployment environment -> (options file, class lib/main.dart selects).
OPTIONS = {
    "production": ("lib/firebase_options_prod.dart", "ProdFirebaseOptions"),
}
DEFAULT_OPTIONS = ("lib/firebase_options.dart", "DefaultFirebaseOptions")


def options_target(environment: str) -> tuple[str, str]:
    return OPTIONS.get(environment, DEFAULT_OPTIONS)


def render_options(config: dict, class_name: str) -> str:
    args = "".join(
        f"    {name}: {json.dumps(config[key])},\n"
        for name, key in FIELDS.items()
        if config.get(key)
    )
    configured = "  static const bool configured = true;\n\n" if class_name != DEFAULT_OPTIONS[1] else ""
    return (
        "// Generated in CI by scripts/web/write_web_config.py; web only.\n"
        "import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;\n"
        "import 'package:flutter/foundation.dart' show kIsWeb;\n\n"
        f"class {class_name} {{\n"
        f"{configured}"
        "  static FirebaseOptions get currentPlatform {\n"
        "    if (kIsWeb) return web;\n"
        "    throw UnsupportedError('Only web FirebaseOptions are configured.');\n"
        "  }\n\n"
        f"  static const FirebaseOptions web = FirebaseOptions(\n{args}  );\n"
        "}\n"
    )


def main():
    config = json.load(sys.stdin)["result"]["sdkConfig"]
    expected = os.environ.get("PROJECT_ID", "").strip()
    if expected and config.get("projectId") != expected:
        raise SystemExit(
            f"Firebase returned config for project {config.get('projectId')!r}, expected {expected!r}; nothing written."
        )
    path, class_name = options_target(os.environ.get("DEPLOY_ENVIRONMENT", "").strip() or "test")
    with open(path, "w") as out:
        out.write(render_options(config, class_name))

    hosting = {
        "site": os.environ.get("SITE_ID") or config["projectId"],
        "public": "build/web",
        "ignore": ["firebase.json", "**/node_modules/**", "**/*.js.map"],
        "rewrites": [{"source": "**", "destination": "/index.html"}],
    }
    apk_url = os.environ.get("ANDROID_APK_URL", "").strip()
    if apk_url:
        if not apk_url.startswith("https://"):
            raise SystemExit("ANDROID_APK_URL must be an https URL")
        hosting["redirects"] = [{"source": "/android", "destination": apk_url, "type": 302}]
    with open("firebase.json", "w") as out:
        json.dump({"hosting": hosting}, out, indent=2)


if __name__ == "__main__":
    main()
