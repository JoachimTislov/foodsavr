"""Validate, render, and recover local Flutter Firebase client options."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from tempfile import NamedTemporaryFile

ANDROID_PACKAGE = "com.foodsavr.app"
WEB_FIELDS = (
    "apiKey", "appId", "messagingSenderId", "projectId", "authDomain",
    "storageBucket", "measurementId", "databaseURL",
)
REQUIRED_FIELDS = WEB_FIELDS[:4]
STUB_MARKERS = ("Compile-only stub written by scripts/ci/local_ci.py", "foodsavr-local-dev")


def validate(content: bytes, *, syntax=False) -> str:
    try:
        source = content.decode("utf-8")
    except UnicodeDecodeError:
        raise ValueError("Firebase options must be UTF-8 Dart.") from None
    if (
        not re.search(r"(?m)^\s*class\s+DefaultFirebaseOptions\s*\{", source)
        or not re.search(r"\bFirebaseOptions\s*\(", source)
        or any(marker in source for marker in STUB_MARKERS)
    ):
        raise ValueError("Firebase options must define DefaultFirebaseOptions and construct FirebaseOptions.")
    if syntax:
        try:
            parsed = subprocess.run(
                ["dart", "format", "--output=none"], input=content,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30,
            )
        except (OSError, subprocess.TimeoutExpired):
            raise ValueError("Install the Flutter SDK to validate Firebase options.") from None
        if parsed.returncode:
            raise ValueError("Firebase options contain invalid Dart syntax.")
    return source


def fingerprint(path, project, web_app):
    """Return the digest only for valid options belonging to the selected deployment."""
    if not project or not web_app:
        return None
    try:
        content = path.read_bytes()
        source = validate(content, syntax=True)
    except (OSError, ValueError):
        return None
    if not re.search(rf"""\bprojectId\s*:\s*['"]{re.escape(project)}['"]""", source):
        return None
    if not re.search(rf"""\bappId\s*:\s*['"]{re.escape(web_app)}['"]""", source):
        return None
    return hashlib.sha256(content).hexdigest()


def render(configs):
    def dart_string(value):
        return json.dumps(value, ensure_ascii=False).replace("$", "\\$")

    declarations = []
    for platform, config in configs.items():
        if not all(isinstance(config.get(field), str) and config[field] for field in REQUIRED_FIELDS):
            raise ValueError(f"The Firebase {platform} configuration is incomplete.")
        args = "".join(
            f"    {name}: {dart_string(config[name])},\n"
            for name in WEB_FIELDS if isinstance(config.get(name), str) and config[name]
        )
        declarations.append(f"  static const FirebaseOptions {platform} = FirebaseOptions(\n{args}  );\n")

    mobile = "defaultTargetPlatform == TargetPlatform.android" if "android" in configs else ""
    imports = "kIsWeb, defaultTargetPlatform, TargetPlatform" if mobile else "kIsWeb"
    branches = "    if (kIsWeb) return web;\n"
    if mobile:
        branches += f"    if ({mobile}) return android;\n"
    return (
        "// Generated from the Firebase project.\n"
        "import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;\n"
        f"import 'package:flutter/foundation.dart' show {imports};\n\n"
        "class DefaultFirebaseOptions {\n"
        "  static FirebaseOptions get currentPlatform {\n"
        f"{branches}"
        "    throw UnsupportedError('FirebaseOptions are unavailable for this platform.');\n"
        "  }\n\n"
        + "\n".join(declarations)
        + "}\n"
    ).encode("utf-8")


def firebase_cli(project, *args):
    try:
        response = subprocess.run(
            ["firebase", *args, "--project", project, "--non-interactive", "--json"],
            capture_output=True, text=True, timeout=60,
        )
        data = json.loads(response.stdout)
        if response.returncode == 0:
            return data["result"]
    except (OSError, subprocess.TimeoutExpired, ValueError, KeyError):
        pass
    raise ValueError("Sign in to the Firebase CLI with access to this project.")


def android_options(config, app_id):
    project = config["project_info"]
    clients = [
        client for client in config["client"]
        if client["client_info"]["mobilesdk_app_id"] == app_id
        and client["client_info"]["android_client_info"]["package_name"] == ANDROID_PACKAGE
    ]
    if len(clients) != 1 or not clients[0].get("api_key"):
        raise ValueError(f"Check the Firebase Android registration for {ANDROID_PACKAGE}.")
    return {
        "apiKey": clients[0]["api_key"][0]["current_key"],
        "appId": app_id,
        "messagingSenderId": project["project_number"],
        "projectId": project["project_id"],
        "storageBucket": project.get("storage_bucket"),
        "databaseURL": project.get("firebase_url"),
    }


def regenerate(path, project, web_app, *, read=firebase_cli):
    web_apps = read(project, "apps:list", "WEB")
    android_apps = read(project, "apps:list", "ANDROID")
    if not any(app.get("appId") == web_app for app in web_apps):
        raise ValueError("Check the Web app registration for the selected Firebase project.")
    android_ids = [app["appId"] for app in android_apps if app.get("packageName") == ANDROID_PACKAGE]
    if len(android_ids) != 1:
        raise ValueError(f"Check the Firebase Android registration for {ANDROID_PACKAGE}.")
    android_id = android_ids[0]
    try:
        web = read(project, "apps:sdkconfig", "WEB", web_app)["sdkConfig"]
        android = android_options(
            json.loads(read(project, "apps:sdkconfig", "ANDROID", android_id)["fileContents"]), android_id,
        )
        if web["appId"] != web_app or web["projectId"] != project or android["projectId"] != project:
            raise ValueError("Firebase returned configuration from a different project or app.")
    except (KeyError, TypeError) as error:
        raise ValueError("Check the Firebase Web and Android SDK configuration.") from error
    content = render({"web": web, "android": android})
    validate(content, syntax=True)
    with NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
        temporary.write(content)
    Path(temporary.name).replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--syntax", action="store_true")
    args = parser.parse_args()
    try:
        validate(args.path.read_bytes(), syntax=args.syntax)
    except (OSError, ValueError) as error:
        sys.exit(str(error))


if __name__ == "__main__":
    main()
