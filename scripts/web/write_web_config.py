#!/usr/bin/env python3
"""Write web-only lib/firebase_options.dart and firebase.json for Hosting.

stdin: `firebase apps:sdkconfig WEB <appId> --json` output.
env:   ANDROID_APK_URL (optional) -> /android redirect.
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


def main():
    config = json.load(sys.stdin)["result"]["sdkConfig"]
    args = "".join(
        f"    {name}: {json.dumps(config[key])},\n"
        for name, key in FIELDS.items()
        if config.get(key)
    )
    with open("lib/firebase_options.dart", "w") as out:
        out.write(
            "// Generated in CI by scripts/web/write_web_config.py; web only.\n"
            "import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;\n"
            "import 'package:flutter/foundation.dart' show kIsWeb;\n\n"
            "class DefaultFirebaseOptions {\n"
            "  static FirebaseOptions get currentPlatform {\n"
            "    if (kIsWeb) return web;\n"
            "    throw UnsupportedError('Only web FirebaseOptions are configured.');\n"
            "  }\n\n"
            f"  static const FirebaseOptions web = FirebaseOptions(\n{args}  );\n"
            "}\n"
        )

    hosting = {
        "site": config["projectId"],
        "public": "build/web",
        "ignore": ["firebase.json", "**/node_modules/**"],
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
