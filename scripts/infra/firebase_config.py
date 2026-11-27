#!/usr/bin/env python3
"""Firebase Auth project settings Terraform cannot own on Spark, plus a read-only health check.

  firebase_config.py plan  [--project P --sites JSON]   exit 0: in sync, 2: changes pending
  firebase_config.py apply [--project P --sites JSON]   add missing settings, never remove any
  firebase_config.py check                              Firestore, rules, Auth, Android App Check readiness
  firebase_config.py providers | provider-secrets       Terraform inputs for auth.tf (from env or .env)

Owns the Email/Password and Anonymous sign-in switches and the authorized
domains of every Hosting site (google_identity_platform_config needs billing
to create, records the password hash key in state and replaces the whole
domain list). Domains added at runtime (Hosting preview channels) are kept.
The Google and Facebook providers are Terraform resources (infra/terraform/gcp/auth.tf).

Without --project the environment is ENV, else production when provisioned,
else test (as scripts/infra/apply.sh). Secret fields of API responses
(signIn.hashConfig, clientSecret) are dropped on read and never printed.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
IDENTITY_TOOLKIT = "https://identitytoolkit.googleapis.com/admin/v2/projects/{project}"
FIRESTORE = "https://firestore.googleapis.com/v1/projects/{project}/databases/(default)"
RULES = "https://firebaserules.googleapis.com/v1/projects/{project}"
CONSOLE = "https://console.firebase.google.com/project/{project}/authentication"
APP_CHECK = "https://firebaseappcheck.googleapis.com/v1beta/projects/{project}"
FIREBASE = "https://firebase.googleapis.com/v1beta1/projects/{project}"
ANDROID_PACKAGE = "com.foodsavr.app"

# Sign-in methods the app uses (lib/services/firebase_auth_service.dart):
# email + password sign-in, sign-up and reset, and guest (anonymous) users.
SIGN_IN = {
    "signIn.email.enabled": True,
    "signIn.email.passwordRequired": True,
    "signIn.anonymous.enabled": True,
}


class ApiError(Exception):
    pass


def desired_domains(project: str, sites: list[str]) -> list[str]:
    """localhost plus both live domains of the default and every channel Hosting site."""
    domains = ["localhost"]
    for site in dict.fromkeys([project, *sites]):
        domains += [f"{site}.firebaseapp.com", f"{site}.web.app"]
    return domains


def lookup(data: dict[str, Any], dotted: str) -> Any:
    for key in dotted.split("."):
        data = data.get(key) if isinstance(data, dict) else None
    return data


def redact(config: dict[str, Any]) -> dict[str, Any]:
    config = dict(config)
    if isinstance(config.get("signIn"), dict):
        config["signIn"] = {k: v for k, v in config["signIn"].items() if k != "hashConfig"}
    config.pop("clientSecret", None)
    return config


def changes(config: dict[str, Any], project: str, sites: list[str]) -> tuple[list[str], list[str]]:
    """(sign-in fields to set, domains to add); existing domains are never removed."""
    fields = [path for path, value in SIGN_IN.items() if lookup(config, path) is not value]
    present = set(config.get("authorizedDomains") or [])
    return fields, [d for d in desired_domains(project, sites) if d not in present]


def patch_body(config: dict[str, Any], fields: list[str], domains: list[str]) -> tuple[str, dict[str, Any]]:
    body: dict[str, Any] = {}
    for path in fields:
        node = body
        *parents, leaf = path.split(".")
        for key in parents:
            node = node.setdefault(key, {})
        node[leaf] = SIGN_IN[path]
    mask = list(fields)
    if domains:
        body["authorizedDomains"] = [*(config.get("authorizedDomains") or []), *domains]
        mask.append("authorizedDomains")
    return ",".join(mask), body


class Client:
    def __init__(self, project: str, token: str, opener: Callable[..., Any] = urlopen):
        self.project, self.token, self.opener = project, token, opener

    def call(self, url: str, method: str = "GET", body: dict[str, Any] | None = None, missing_ok: bool = False) -> dict[str, Any]:
        headers = {"Authorization": f"Bearer {self.token}", "x-goog-user-project": self.project}
        data = None
        if body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        try:
            with self.opener(Request(url, data=data, headers=headers, method=method), timeout=30) as response:
                result = json.load(response)
        except HTTPError as error:
            text = error.read().decode(errors="ignore")
            error.close()
            if missing_ok and (error.code == 404 or "SERVICE_DISABLED" in text or "CONFIGURATION_NOT_FOUND" in text):
                return {}
            raise ApiError(f"{method} {url.split('?')[0]} failed (HTTP {error.code}).") from None
        except (OSError, URLError, ValueError):
            raise ApiError(f"{method} {url.split('?')[0]} failed.") from None
        return redact(result) if isinstance(result, dict) else {}

    def auth_config(self) -> dict[str, Any]:
        return self.call(f"{IDENTITY_TOOLKIT.format(project=self.project)}/config", missing_ok=True)


def reconcile(client: Client, sites: list[str], apply: bool) -> int:
    project = client.project
    config = client.auth_config()
    if not config:
        print(f"Firebase Auth: not available yet in {project} (Identity Toolkit API disabled or Auth not started).")
        if apply:
            print(f"Open {CONSOLE.format(project=project)}, click Get started, then re-run.", file=sys.stderr)
            return 1
        return 2
    fields, domains = changes(config, project, sites)
    if not fields and not domains:
        print("Firebase Auth: sign-in methods and authorized domains are in sync.")
        return 0
    for path in fields:
        print(f"Firebase Auth: set {path} = {str(SIGN_IN[path]).lower()}")
    for domain in domains:
        print(f"Firebase Auth: add authorized domain {domain}")
    if not apply:
        return 2
    mask, body = patch_body(config, fields, domains)
    client.call(f"{IDENTITY_TOOLKIT.format(project=project)}/config?updateMask={mask}", "PATCH", body)
    print("Firebase Auth: updated.")
    return 0


def check(client: Client, sites: list[str], rules: str) -> list[str]:
    """Problems with the declared Firebase state; empty when healthy."""
    project, problems = client.project, []
    database = client.call(FIRESTORE.format(project=project), missing_ok=True)
    if not database:
        problems.append("Firestore (default) database is missing")
    release = client.call(f"{RULES.format(project=project)}/releases/cloud.firestore", missing_ok=True)
    if not release.get("rulesetName"):
        problems.append("no Firestore rules release")
    else:
        ruleset = client.call(f"https://firebaserules.googleapis.com/v1/{release['rulesetName']}")
        files = (ruleset.get("source") or {}).get("files") or [{}]
        if (files[0].get("content") or "").rstrip("\n") != rules.rstrip("\n"):
            problems.append("released Firestore rules differ from firestore.rules")
    config = client.auth_config()
    if not config:
        problems.append("Firebase Auth is not started")
    else:
        fields, domains = changes(config, project, sites)
        problems += [f"Auth {path} is not {str(SIGN_IN[path]).lower()}" for path in fields]
        problems += [f"authorized domain {domain} is missing" for domain in domains]
    # Play Integrity verifies the app by its signing certificate; without one,
    # Android gets no App Check token once Firestore is enforced.
    service = client.call(f"{APP_CHECK.format(project=project)}/services/firestore.googleapis.com", missing_ok=True)
    if service.get("enforcementMode") == "ENFORCED":
        apps = client.call(f"{FIREBASE.format(project=project)}/androidApps?pageSize=100", missing_ok=True).get("apps", [])
        for app in apps:
            if app.get("packageName") != ANDROID_PACKAGE:
                continue
            certificates = client.call(f"{FIREBASE.format(project=project)}/androidApps/{app['appId']}/sha", missing_ok=True)
            if not any(c.get("certType") == "SHA_256" for c in certificates.get("certificates", [])):
                problems.append(f"Android app {ANDROID_PACKAGE} has no SHA-256 fingerprint for Play Integrity "
                                "(scripts/setup/social_auth.sh with EXTRA_SHA=<Play signing SHA-256>)")
    return problems


def env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip().removeprefix("export ").strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
            value = value[1:-1]
        values[key] = value
    return values


def web_client_id(root: Path) -> str:
    """The Google web OAuth client (client_type 3) Firebase lists in google-services.json."""
    try:
        data = json.loads((root / "android/app/google-services.json").read_text())
    except (OSError, ValueError):
        return ""
    return next((o.get("client_id", "") for c in data.get("client", []) for o in c.get("oauth_client", [])
                 if o.get("client_type") == 3), "")


def credentials(root: Path = ROOT, environ: dict[str, str] | None = None) -> dict[str, tuple[str, str]]:
    """Providers with complete credentials: idp -> (public client id, secret). Never printed together."""
    source = {**env_file(root / ".env"), **{k: v for k, v in (os.environ if environ is None else environ).items() if v}}
    found = {
        "google.com": (source.get("GOOGLE_WEB_CLIENT_ID") or web_client_id(root), source.get("GOOGLE_WEB_CLIENT_SECRET", "")),
        "facebook.com": (source.get("FACEBOOK_APP_ID", ""), source.get("FACEBOOK_APP_SECRET", "")),
    }
    return {idp: pair for idp, pair in found.items() if all(pair)}


def levels(env: str, fmt: str) -> str:
    manifest = os.environ.get("MANIFEST") or str(ROOT / "deploy/instance.yaml")
    result = subprocess.run(
        ["dart", "run", "bin/levels.dart", "env", "--manifest", manifest, "--env", env, "--format", fmt],
        cwd=ROOT / "packages/foodsavr_deploy", capture_output=True, text=True, timeout=120,
    )
    if result.returncode:
        raise ApiError(f"Cannot read environment {env} from the deployment manifest.")
    return result.stdout


def dotenv(text: str) -> dict[str, str]:
    return {key: (shlex.split(value) or [""])[0] for line in text.splitlines() if "=" in line
            for key, value in [line.split("=", 1)]}


def resolve() -> tuple[str, list[str]]:
    env = os.environ.get("ENV") or ""
    if not env:
        env = "production" if dotenv(levels("production", "dotenv")).get("PROVISIONED") == "true" else "test"
    values = dotenv(levels(env, "dotenv"))
    if values.get("PROVISIONED") != "true" or values.get("EMULATOR") == "true":
        raise ApiError(f"Environment {env} has no provisioned Firebase project.")
    sites = next((json.loads(line.split("=", 1)[1]) for line in levels(env, "tfvars").splitlines()
                  if line.startswith("hosting_sites =")), [])
    return values["PROJECT_ID"], sites


def token() -> str:
    if os.environ.get("GOOGLE_OAUTH_ACCESS_TOKEN"):
        return os.environ["GOOGLE_OAUTH_ACCESS_TOKEN"]
    account = os.environ.get("GCLOUD_ACCOUNT")
    result = subprocess.run(["gcloud", *([f"--account={account}"] if account else []), "auth", "print-access-token"],
                            capture_output=True, text=True, timeout=30)
    if result.returncode or not result.stdout.strip():
        raise ApiError("gcloud is not signed in; run gcloud auth login.")
    return result.stdout.strip()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=("plan", "apply", "check", "providers", "provider-secrets"))
    parser.add_argument("--project")
    parser.add_argument("--sites", default="[]", help="JSON list of channel Hosting sites")
    args = parser.parse_args(argv)
    if args.action in ("providers", "provider-secrets"):
        found = credentials()
        index = 0 if args.action == "providers" else 1
        print(json.dumps({idp: ({"client_id": pair[0]} if index == 0 else pair[1]) for idp, pair in found.items()}))
        return 0
    try:
        project, sites = (args.project, json.loads(args.sites or "[]")) if args.project else resolve()
        client = Client(project, token())
        if args.action == "check":
            problems = check(client, sites, (ROOT / "firestore.rules").read_text())
            for problem in problems:
                print(f"{project}: {problem}")
            print(f"{project}: Firebase configuration {'needs attention' if problems else 'matches the declared state'}.")
            return 1 if problems else 0
        return reconcile(client, sites, args.action == "apply")
    except (ApiError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
