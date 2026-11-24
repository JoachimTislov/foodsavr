#!/usr/bin/env python3
"""Idempotently check or enable Firebase Auth Facebook sign-in via Identity Toolkit API."""

from __future__ import annotations

import argparse
from collections.abc import Callable, Mapping
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
PROVIDER_ID = "facebook.com"
IDENTITY_TOOLKIT_BASE = "https://identitytoolkit.googleapis.com/admin/v2/projects"
CONSOLE_URL = "https://console.firebase.google.com/project/{project}/authentication/providers"


def load_env_file(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] == "'":
            value = value[1:-1].replace("'\\''", "'")
        elif len(value) >= 2 and value[0] == value[-1] == '"':
            value = value[1:-1]
        values[key] = value
    return values


def load_facebook_credentials(root: Path = ROOT, env: Mapping[str, str] | None = None) -> tuple[str, str]:
    source = os.environ if env is None else env
    values = load_env_file(root / ".env")
    return (
        source.get("FACEBOOK_APP_ID") or values.get("FACEBOOK_APP_ID", ""),
        source.get("FACEBOOK_APP_SECRET") or values.get("FACEBOOK_APP_SECRET", ""),
    )


def identity_toolkit_token(account: str | None = None) -> str:
    command = ["gcloud", *([f"--account={account}"] if account else []), "auth", "print-access-token"]
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=20, check=True).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def providers_console_url(project: str) -> str:
    if not project:
        return "https://console.firebase.google.com/"
    return CONSOLE_URL.format(project=project)


def sync_facebook_provider(
    project: str,
    app_id: str,
    app_secret: str,
    *,
    account: str | None = None,
    check: bool = False,
    get_token: Callable[[str | None], str] | None = None,
    open_url: Callable[..., object] | None = None,
) -> tuple[bool, str]:
    """Check or idempotently configure the Firebase Auth Facebook provider."""
    token_fn = identity_toolkit_token if get_token is None else get_token
    url_fn = urlopen if open_url is None else open_url

    console_url = providers_console_url(project)
    if not project:
        return False, f"Firebase project is not configured; open {console_url}"

    token = token_fn(account)
    if not token:
        return False, f"Could not access {PROVIDER_ID} via API; open {console_url}"

    base = f"{IDENTITY_TOOLKIT_BASE}/{project}/defaultSupportedIdpConfigs"
    headers = {
        "Authorization": f"Bearer {token}",
        "x-goog-user-project": project,
    }

    exists = False
    current: dict[str, object] | None = None
    try:
        with url_fn(Request(f"{base}/{PROVIDER_ID}", headers=headers), timeout=20) as response:
            parsed = json.load(response)
            if not isinstance(parsed, dict):
                return False, f"Could not access {PROVIDER_ID} via API; open {console_url}"
            current = parsed
            exists = True
    except HTTPError as error:
        code = error.code
        error.close()
        if code != 404:
            return False, f"Could not access {PROVIDER_ID} via API (HTTP {code}); open {console_url}"
    except (OSError, URLError, ValueError):
        return False, f"Could not access {PROVIDER_ID} via API; open {console_url}"

    if exists and current is not None:
        enabled = current.get("enabled") is True
        current_id = current.get("clientId", "")
        current_secret = current.get("clientSecret")
        id_matches = (not app_id) or (current_id == app_id)
        secret_matches = (not app_secret) or (current_secret is None) or (current_secret == app_secret)
        if enabled and id_matches and secret_matches:
            return True, f"{PROVIDER_ID} is enabled"

    if check:
        if exists and current is not None and current.get("enabled") is True:
            return False, f"{PROVIDER_ID} uses a different app configuration"
        return False, f"{PROVIDER_ID} is disabled"

    if not app_id or not app_secret:
        return (
            False,
            f"{PROVIDER_ID} is disabled; run scripts/human/meta/create-app-credentials.sh, then re-run",
        )

    method = "PATCH" if exists else "POST"
    target = (
        f"{base}/{PROVIDER_ID}?updateMask=enabled,clientId,clientSecret"
        if exists
        else f"{base}?idpId={PROVIDER_ID}"
    )
    payload = json.dumps({"enabled": True, "clientId": app_id, "clientSecret": app_secret}).encode("utf-8")
    write_headers = {**headers, "Content-Type": "application/json"}
    try:
        with url_fn(Request(target, data=payload, headers=write_headers, method=method), timeout=20) as response:
            data = json.load(response)
            if isinstance(data, dict) and data.get("enabled") is True:
                return True, f"{PROVIDER_ID} enabled"
    except HTTPError as error:
        code = error.code
        error.close()
        return False, f"Could not update {PROVIDER_ID} via API (HTTP {code}); open {console_url}"
    except (OSError, URLError, ValueError):
        return False, f"Could not update {PROVIDER_ID} via API; open {console_url}"
    return False, f"Could not update {PROVIDER_ID} via API; open {console_url}"


def enable_facebook_provider(
    project: str,
    account: str | None,
    app_id: str,
    app_secret: str,
    *,
    get_token: Callable[[str | None], str] | None = None,
    open_url: Callable[..., object] | None = None,
) -> bool:
    if not project or not app_id or not app_secret:
        return False
    ok, _ = sync_facebook_provider(
        project,
        app_id,
        app_secret,
        account=account,
        check=False,
        get_token=get_token,
        open_url=open_url,
    )
    return ok


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project")
    parser.add_argument("--account", default=os.environ.get("GCLOUD_ACCOUNT"))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)

    app_id, app_secret = load_facebook_credentials(ROOT)
    ok, message = sync_facebook_provider(
        args.project,
        app_id,
        app_secret,
        account=args.account,
        check=args.check,
    )
    print(message)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
