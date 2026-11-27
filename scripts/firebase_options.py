"""Firebase client options as compile-time defines (lib/firebase_options.dart).

The repository tracks no project ids: setup writes the environment's options
to the gitignored `.agents/state/firebase.defines.json`, which builds pass with
`--dart-define-from-file`. Worktrees read the main checkout's file.

    python3 scripts/firebase_options.py path        # resolved defines file
    python3 scripts/firebase_options.py flags       # `--dart-define-from-file=...` or nothing
    python3 scripts/firebase_options.py validate [FILE]
"""

import argparse
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import sys
from tempfile import NamedTemporaryFile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import instance_local  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RELATIVE = Path(".agents/state/firebase.defines.json")
ANDROID_PACKAGE = "com.foodsavr.app"
# Define name -> (platform, sdk config key). Shared keys come from the web config.
DEFINES = {
    "FIREBASE_PROJECT_ID": ("web", "projectId"),
    "FIREBASE_MESSAGING_SENDER_ID": ("web", "messagingSenderId"),
    "FIREBASE_STORAGE_BUCKET": ("web", "storageBucket"),
    "FIREBASE_AUTH_DOMAIN": ("web", "authDomain"),
    "FIREBASE_MEASUREMENT_ID": ("web", "measurementId"),
    "FIREBASE_WEB_API_KEY": ("web", "apiKey"),
    "FIREBASE_WEB_APP_ID": ("web", "appId"),
    "FIREBASE_ANDROID_API_KEY": ("android", "apiKey"),
    "FIREBASE_ANDROID_APP_ID": ("android", "appId"),
}
REQUIRED = ("FIREBASE_PROJECT_ID", "FIREBASE_MESSAGING_SENDER_ID", "FIREBASE_WEB_API_KEY", "FIREBASE_WEB_APP_ID")


def defines_path(root: Path = ROOT) -> Path:
    """This worktree's defines file when present, else the main checkout's (where setup writes)."""
    own = root / RELATIVE
    if own.is_file():
        return own
    main = instance_local.main_checkout(root)
    return main / RELATIVE if main else own


def validate(content: bytes) -> dict:
    try:
        defines = json.loads(content.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        raise ValueError("Firebase defines must be a UTF-8 JSON object.") from None
    if not isinstance(defines, dict) or not all(isinstance(defines.get(name), str) and defines[name] for name in REQUIRED):
        raise ValueError(f"Firebase defines need {', '.join(REQUIRED)}.")
    unknown = set(defines) - set(DEFINES)
    if unknown:
        raise ValueError(f"Unknown Firebase defines: {', '.join(sorted(unknown))}.")
    return defines


def fingerprint(path, project, web_app):
    """Return the digest only for valid defines belonging to the selected deployment."""
    if not project or not web_app:
        return None
    try:
        content = Path(path).read_bytes()
        defines = validate(content)
    except (OSError, ValueError):
        return None
    if (defines["FIREBASE_PROJECT_ID"], defines["FIREBASE_WEB_APP_ID"]) != (project, web_app):
        return None
    return hashlib.sha256(content).hexdigest()


def render(configs) -> bytes:
    """Defines JSON from {"web": sdkconfig, "android": options}; android is optional."""
    web = configs.get("web") or {}
    if not all(isinstance(web.get(key), str) and web[key] for key in ("apiKey", "appId", "messagingSenderId", "projectId")):
        raise ValueError("The Firebase web configuration is incomplete.")
    defines = {}
    for name, (platform, key) in DEFINES.items():
        value = (configs.get(platform) or {}).get(key)
        if isinstance(value, str) and value:
            defines[name] = value
    return (json.dumps(defines, indent=2, sort_keys=True) + "\n").encode("utf-8")


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
    validate(content)
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=path.parent, delete=False) as temporary:
        temporary.write(content)
    Path(temporary.name).replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=("path", "flags", "validate"))
    parser.add_argument("file", nargs="?", type=Path)
    args = parser.parse_args()
    path = args.file or defines_path()
    if args.command == "path":
        print(path)
    elif args.command == "flags":
        if path.is_file():
            # Make recipes splice this into a shell command; quote paths with spaces.
            print(shlex.quote(f"--dart-define-from-file={path}"))
    else:
        try:
            validate(path.read_bytes())
        except (OSError, ValueError) as error:
            sys.exit(str(error))


if __name__ == "__main__":
    main()
