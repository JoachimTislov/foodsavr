#!/usr/bin/env python3
"""Build the web app and deploy it to Firebase Hosting.

One implementation for the hosting jobs of `.github/workflows/release.yml` and for
`make deploy-web` (the manual bypass), so the two cannot drift.

Workflow steps (configuration comes from the environment the workflow sets):
  build        write web config and assets/.env, build web into build/web
  sourcemaps   upload web source maps to Crashlytics (Blaze, live only)
  guard        keep Hosting storage in budget; sets `channel` and `fits`
  deploy       deploy a preview channel or live

Manual bypass:
  local --env ENV [--channel CHANNEL] [--target live|preview]   run all of the
        above with your own `firebase login`, CI's pinned Flutter and the
        manifest in deploy/instance.yaml; the channel picks the environment's
        Hosting site (the first release site for live and the default site
        for previews when omitted). CHANNEL in the environment also works,
        e.g. `make deploy-web ENV=test CHANNEL=daily`. An explicit channel
        must belong to the selected environment. Actions
        variables are read with `gh variable get` when not set in the
        environment.

Environment: PROJECT_ID, WEB_APP_ID, SITE_ID, FLAVOR (the manifest
environment, e.g. test or production), TARGET (live|preview), BRANCH, EXPIRES,
FIREBASE_TOOLS, WEB_ENV_B64 or WEB_ENV_FILE (assets/.env, served publicly;
empty when neither is set), ANDROID_APK_URL, RECAPTCHA_ENTERPRISE_SITE_KEY,
FIREBASE_PLAN, ERROR_REPORTER, ERROR_COLLECTOR_ENDPOINT.

Every hosted build uses the app's remote-backend flavor (`production`) and
selects its Firebase project with `--dart-define=DEPLOY_ENVIRONMENT=<env>`
(lib/main.dart), so a test deploy never ships production options and a
production deploy never falls back to the test project.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_FIREBASE_TOOLS = "firebase-tools@15"
EXPIRES = re.compile(r"^[0-9]+[hdw]$")
TARGETS = ("live", "preview")
# Files the build rewrites; `local` restores them so a manual deploy leaves your checkout as it was.
TOUCHED = ("lib/firebase_options.dart", "lib/firebase_options_prod.dart", "assets/.env", "firebase.json")
# App flavor of every hosted build: the remote backend. The manifest environment
# (test, staging, production) is passed separately as DEPLOY_ENVIRONMENT.
APP_FLAVOR = "production"


def in_actions() -> bool:
    return os.environ.get("GITHUB_ACTIONS") == "true"


def warn(message: str) -> None:
    print(f"::warning::{message}" if in_actions() else f"warning: {message}", flush=True)


def fail(message: str) -> None:
    raise SystemExit(f"::error::{message}" if in_actions() else f"error: {message}")


def tools() -> str:
    return os.environ.get("FIREBASE_TOOLS") or DEFAULT_FIREBASE_TOOLS


def firebase(*args: str) -> list[str]:
    return ["npx", "-y", tools(), *args]


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=ROOT, check=True, **kwargs)


def channel_name(branch: str) -> str:
    """Preview channel for a branch: sanitized prefix plus a digest of the full name."""
    prefix = re.sub(r"[^a-z0-9-]", "-", branch.lower())[:27].strip("-")
    digest = hashlib.sha256(branch.encode()).hexdigest()[:12]
    return f"{prefix or 'branch'}-{digest}"


def check_expires(expires: str) -> str:
    if not EXPIRES.match(expires):
        fail("expires must look like 4h, 1d or 2w")
    return expires


def build_defines(environment: str, recaptcha: str = "", reporter: str = "", endpoint: str = "", *,
                  access_code: str = "", legal_environment: str = "") -> list[str]:
    defines = [f"--dart-define=FLAVOR={APP_FLAVOR}", f"--dart-define=DEPLOY_ENVIRONMENT={environment}"]
    if access_code:
        defines.append(f"--dart-define=WEB_ACCESS_CODE={access_code}")
    if legal_environment:
        defines.append(f"--dart-define=LEGAL_ENVIRONMENT={legal_environment}")
    if recaptcha:
        defines.append(f"--dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY={recaptcha}")
    else:
        warn("RECAPTCHA_ENTERPRISE_SITE_KEY is missing; App Check uses a placeholder key.")
    if reporter:
        defines.append(f"--dart-define=ERROR_REPORTER={reporter}")
    if endpoint:
        defines.append(f"--dart-define=ERROR_COLLECTOR_ENDPOINT={endpoint}")
    return defines


def build_flags(plan: str, target: str) -> list[str]:
    flags = ["--release"]
    if plan == "blaze" and target == "live":
        flags.append("--source-maps")
    return flags


def required(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        fail(f"{name} is not set")
    return value


def write_dotenv() -> None:
    target = ROOT / "assets/.env"
    target.parent.mkdir(parents=True, exist_ok=True)
    encoded, source = os.environ.get("WEB_ENV_B64", ""), os.environ.get("WEB_ENV_FILE", "")
    if encoded:
        try:
            decoded = base64.b64decode(encoded.replace("\r", "").replace("\n", ""), validate=True)
        except ValueError:
            fail("WEB_ENV_B64 is not valid Base64")
        target.write_bytes(decoded)
    elif source:
        source_path = Path(source)
        if not source_path.is_file():
            fail(f"WEB_ENV_FILE {source} does not exist")
        if not target.exists() or not source_path.samefile(target):
            shutil.copyfile(source_path, target)
    else:
        warn("No assets/.env source (WEB_ENV_B64 or WEB_ENV_FILE); deploying with an empty assets/.env.")
        target.write_text("")


def cmd_build() -> None:
    project, app = required("PROJECT_ID"), required("WEB_APP_ID")
    environment, target = required("FLAVOR"), os.environ.get("TARGET", "live")
    revision = build_revision()
    config = run(firebase("apps:sdkconfig", "WEB", app, "--project", project, "--json"), capture_output=True, text=True)
    run(["python3", "scripts/web/write_web_config.py"], input=config.stdout, text=True,
        env={**os.environ, "DEPLOY_ENVIRONMENT": environment})
    write_dotenv()
    run(["flutter", "pub", "get"])
    run(["dart", "run", "build_runner", "build", "--delete-conflicting-outputs"])
    run(["flutter", "create", ".", "--platforms", "web"])
    defines = build_defines(
        environment,
        os.environ.get("RECAPTCHA_ENTERPRISE_SITE_KEY", ""),
        os.environ.get("ERROR_REPORTER", ""),
        os.environ.get("ERROR_COLLECTOR_ENDPOINT", ""),
        access_code=os.environ.get("WEB_ACCESS_CODE", ""),
        # ADR 0009: each environment ships its own legal documents.
        legal_environment=environment,
    )
    run(["flutter", "build", "web", *build_flags(os.environ.get("FIREBASE_PLAN", ""), target), *defines])
    write_release_metadata(ROOT / "build/web", revision)
    write_landing_config(ROOT / "build/web/about/config.js", environment)


def write_landing_config(output: Path, environment: str) -> None:
    if not output.parent.is_dir():
        return
    legal_env = os.environ.get("LEGAL_ENVIRONMENT", "").strip() or environment
    run(
        ["python3", "scripts/web/write_landing_config.py", str(output)],
        env={**os.environ, "LEGAL_ENVIRONMENT": legal_env},
    )


def build_revision() -> str:
    revision = run(["git", "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    if run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout:
        warn("Checkout has local changes. Release metadata will omit the commit SHA.")
        return ""
    return revision


def write_release_metadata(build_dir: Path, revision: str) -> None:
    with (build_dir / "main.dart.js").open("rb") as bundle:
        digest = hashlib.file_digest(bundle, "sha256").hexdigest()
    (build_dir / "release.json").write_text(
        json.dumps({"revision": revision, "main_bundle_sha256": digest}) + "\n", encoding="utf-8"
    )


def cmd_sourcemaps() -> None:
    run(firebase("crashlytics:sourcemap:upload", "--app", required("WEB_APP_ID"),
                 "--project", required("PROJECT_ID"), "--clean", "build/web"))


def directory_bytes(path: Path) -> int:
    return sum(p.stat().st_size for p in path.rglob("*") if p.is_file())


def github_output(key: str, value: str) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a") as out:
            out.write(f"{key}={value}\n")


def cmd_guard() -> int:
    target = os.environ.get("TARGET", "live")
    channel = channel_name(os.environ.get("BRANCH", ""))
    github_output("channel", channel)
    env = {**os.environ, "KEEP_CHANNEL": channel if target == "preview" else ""}
    code = subprocess.run(
        ["python3", "scripts/web/hosting_storage_guard.py", target, str(directory_bytes(ROOT / "build/web"))],
        cwd=ROOT, env=env,
    ).returncode
    if code == 3:
        github_output("fits", "false")
        return 3
    if code == 0:
        github_output("fits", "true")
    return code


def preview_url(raw: str) -> str:
    return next(iter(json.loads(raw)["result"].values()))["url"]


def append_summary(line: str) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as out:
            out.write(line + "\n")


def cmd_deploy() -> None:
    project, target = required("PROJECT_ID"), os.environ.get("TARGET", "live")
    if target == "preview":
        expires = check_expires(os.environ.get("EXPIRES", "4h"))
        channel = channel_name(os.environ.get("BRANCH", ""))
        out = run(firebase("hosting:channel:deploy", channel, "--expires", expires, "--project", project, "--json"),
                  capture_output=True, text=True)
        url = preview_url(out.stdout)
        print(f"Preview: {url}")
        append_summary(f"Preview: {url}")
        if in_actions() and os.environ.get("GH_TOKEN"):
            comment_on_pr(os.environ.get("BRANCH", ""), expires, url)
        return
    run(firebase("deploy", "--only", "hosting", "--project", project, "--non-interactive"))
    site = os.environ.get("SITE_ID") or project
    channel = os.environ.get("RELEASE_CHANNEL", "")
    url = f"https://{site}.web.app"
    github_output("url", url)  # release.yml probes the site it deployed
    line = f"Live ({os.environ.get('FLAVOR', '')}{f', {channel}' if channel else ''}): {url}"
    print(line)
    append_summary(line)


def comment_on_pr(branch: str, expires: str, url: str) -> None:
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    found = subprocess.run(
        ["gh", "pr", "list", "--repo", repo, "--head", branch, "--state", "open", "--json", "number",
         "--jq", ".[0].number // empty"],
        capture_output=True, text=True,
    ).stdout.strip()
    if found:
        subprocess.run(
            ["gh", "pr", "comment", found, "--repo", repo, "--edit-last", "--create-if-none",
             "--body", f"🔥 Firebase Hosting preview (expires in {expires}): {url}"],
            check=True,
        )


# --- manual bypass -----------------------------------------------------------


def parse_dotenv(text: str) -> dict[str, str]:
    values = {}
    for line in text.splitlines():
        match = re.match(r"^([A-Z_][A-Z0-9_]*)='(.*)'$", line)
        if match:
            values[match.group(1)] = match.group(2)
    return values


def manifest_env(env_name: str, channel: str = "") -> dict[str, str]:
    deploy = ROOT / "packages/foodsavr_deploy"
    subprocess.run(["dart", "pub", "get"], cwd=deploy, check=True, capture_output=True)
    command = ["dart", "run", "bin/levels.dart", "env", "--env", env_name, "--format", "dotenv"]
    if channel:
        command += ["--channel", channel]
    out = subprocess.run(command, cwd=deploy, capture_output=True, text=True)
    if out.returncode != 0:
        fail(f"cannot resolve environment '{env_name}' from deploy/instance.yaml: {out.stderr.strip()}")
    values = parse_dotenv(out.stdout)
    if values.get("PROVISIONED") == "false":
        fail(f"environment '{env_name}' is not provisioned yet; run make setup to create its Firebase project")
    if not values.get("PROJECT_ID"):
        fail(f"environment '{env_name}' has no Firebase project in deploy/instance.yaml")
    return values


def environment_channels() -> dict[str, list[str]]:
    """Release channels each cloud environment deploys, from deploy/instance.yaml."""
    deploy = ROOT / "packages/foodsavr_deploy"
    out = subprocess.run(["dart", "run", "bin/levels.dart", "environments", "--json"],
                         cwd=deploy, capture_output=True, text=True)
    if out.returncode != 0:
        fail(f"cannot list environments in deploy/instance.yaml: {out.stderr.strip()}")
    try:
        environments = json.loads(out.stdout)
    except ValueError:
        fail("cannot list environments in deploy/instance.yaml")
    return {e["name"]: list(e.get("channels") or []) for e in environments if not e.get("emulator")}


def valid_combinations(channels: dict[str, list[str]]) -> str:
    return "; ".join(f"ENV={name} CHANNEL={'|'.join(served)}" for name, served in channels.items() if served) or "none"


def select_channel(env_name: str, requested: str, target: str) -> str:
    """Channel whose site to deploy. Live deploys need a channel the environment
    deploys (default: its first); previews without a channel use the default site."""
    if target == "preview" and not requested:
        return ""
    channels = environment_channels()
    served = channels.get(env_name, [])
    channel = requested or (served[0] if served else "")
    if channel not in served:
        fail(f"environment '{env_name}' does not deploy channel '{channel or '(none)'}'; "
             f"valid {target} deploys: {valid_combinations(channels)}")
    return channel


def actions_variable(name: str) -> str:
    """Environment first, then the repository's Actions variable via your `gh` login."""
    if os.environ.get(name):
        return os.environ[name]
    if not shutil.which("gh"):
        return ""
    out = subprocess.run(["gh", "variable", "get", name], capture_output=True, text=True)
    return out.stdout.strip() if out.returncode == 0 else ""


def current_branch() -> str:
    out = subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=ROOT, capture_output=True, text=True)
    return out.stdout.strip() or "local"


def pinned_flutter_dir() -> str:
    out = subprocess.run(["python3", "scripts/ci/local_ci.py", "--flutter-bin"], cwd=ROOT, capture_output=True, text=True)
    if out.returncode != 0:
        fail(f"cannot provision CI's pinned Flutter: {out.stderr.strip()}")
    return str(Path(out.stdout.strip()).parent)


def check_firebase_login() -> None:
    out = subprocess.run(firebase("login:list"), cwd=ROOT, capture_output=True, text=True)
    if out.returncode != 0 or "No authorized accounts" in out.stdout + out.stderr:
        fail("no Firebase login; run `npx -y firebase-tools login` first")


@contextmanager
def preserved(paths: tuple[str, ...]):
    snapshot = {p: (ROOT / p).read_bytes() for p in paths if (ROOT / p).is_file()}
    try:
        yield
    finally:
        for rel in paths:
            path = ROOT / rel
            if rel in snapshot:
                path.write_bytes(snapshot[rel])
            else:
                path.unlink(missing_ok=True)


def local_settings(args: argparse.Namespace) -> tuple[dict[str, str], str]:
    """Deploy settings from the manifest, and the Actions variable suffix of the environment."""
    channel = select_channel(args.env, args.channel or os.environ.get("CHANNEL", ""), args.target)
    values = manifest_env(args.env, channel)
    settings = {
        "PROJECT_ID": values["PROJECT_ID"],
        "WEB_APP_ID": values.get("WEB_APP_ID", ""),
        "SITE_ID": values.get("SITE_ID", ""),
        "RELEASE_CHANNEL": values.get("CHANNEL", ""),
        "FLAVOR": values.get("FLAVOR", args.env),
        "TARGET": args.target,
        "BRANCH": args.branch or current_branch(),
        "EXPIRES": args.expires,
    }
    if not settings["WEB_APP_ID"]:
        fail(f"environment '{args.env}' has no web app id in deploy/instance.yaml")
    if args.web_env_file:
        settings["WEB_ENV_FILE"] = args.web_env_file
    return settings, values.get("VAR_SUFFIX", "")


def cmd_local(args: argparse.Namespace) -> int:
    check_expires(args.expires)
    os.environ["PATH"] = f"{pinned_flutter_dir()}{os.pathsep}{os.environ['PATH']}"
    settings, suffix = local_settings(args)
    print(f"Environment {args.env}: project {settings['PROJECT_ID']}, site {settings['SITE_ID'] or settings['PROJECT_ID']}, "
          f"channel {settings['RELEASE_CHANNEL'] or 'none'}, "
          f"target {args.target}, assets/.env from {args.web_env_file or 'nothing (empty)'}")
    if args.plan:
        print("Plan only: no build, no deploy.")
        return 0
    if args.target == "live" and not args.yes:
        if not (sys.stdin.isatty() and sys.stdout.isatty()):
            fail("a live deploy replaces the site; pass YES=1 to confirm without a terminal")
        if input(f"Deploy LIVE to {settings['PROJECT_ID']}? [y/N] ").strip().lower() not in {"y", "yes"}:
            print("Cancelled.")
            return 1
    check_firebase_login()
    optional = {
        "RECAPTCHA_ENTERPRISE_SITE_KEY": actions_variable(f"RECAPTCHA_ENTERPRISE_SITE_KEY{suffix}"),
        "FIREBASE_PLAN": actions_variable("FIREBASE_PLAN"),
        "ERROR_REPORTER": actions_variable("ERROR_REPORTER"),
        "ERROR_COLLECTOR_ENDPOINT": actions_variable("ERROR_COLLECTOR_ENDPOINT"),
        "ANDROID_APK_URL": actions_variable("ANDROID_APK_URL"),
    }
    os.environ.update(settings)
    os.environ.update({k: v for k, v in optional.items() if v})
    with preserved(TOUCHED):
        cmd_build()
        if args.target == "live" and os.environ.get("FIREBASE_PLAN") == "blaze":
            cmd_sourcemaps()
        code = cmd_guard()
        if code == 3:
            fail("the preview would not fit the Hosting storage budget; nothing deployed")
        if code != 0:
            return code
        cmd_deploy()
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("build", "sourcemaps", "guard", "deploy"):
        sub.add_parser(name)
    local = sub.add_parser("local", help="manual bypass: build and deploy with your own logins")
    local.add_argument("--env", required=True, help="environment in deploy/instance.yaml")
    local.add_argument("--channel", default="",
                       help="release channel whose Hosting site to deploy (live default: CHANNEL or the first channel)")
    local.add_argument("--target", choices=TARGETS, default="live")
    local.add_argument("--expires", default="4h", help="preview lifetime, e.g. 4h, 1d, 2w")
    local.add_argument("--branch", default="", help="branch naming the preview channel (default: current)")
    local.add_argument("--web-env-file", default="", help="file copied to assets/.env (served publicly); default empty")
    local.add_argument("--yes", action="store_true", help="confirm a live deploy without prompting")
    local.add_argument("--plan", action="store_true", help="resolve and print the settings, then stop")
    args = parser.parse_args(argv)
    if args.command == "local":
        return cmd_local(args)
    if args.command == "guard":
        # Exit 3 (preview does not fit) is recorded in `fits`; the workflow skips the deploy step.
        code = cmd_guard()
        return 0 if code == 3 else code
    {"build": cmd_build, "sourcemaps": cmd_sourcemaps, "deploy": cmd_deploy}[args.command]()
    return 0


if __name__ == "__main__":
    sys.exit(main())
