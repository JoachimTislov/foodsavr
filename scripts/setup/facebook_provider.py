#!/usr/bin/env python3
"""Check Firebase Auth Facebook sign-in via the Identity Toolkit API (read-only; Terraform owns it)."""

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
    app_secret: str = "",
    *,
    account: str | None = None,
    check: bool = True,
    get_token: Callable[[str | None], str] | None = None,
    open_url: Callable[..., object] | None = None,
) -> tuple[bool, str]:
    """Check the Firebase Auth Facebook provider (read-only).

    Terraform owns the provider (infra/terraform/gcp/auth.tf, applied by
    `make infra-gcp-apply`). The client secret in the API response is
    discarded unread; only `enabled` and the public app ID are compared.
    `app_secret` and `check` are kept for callers and ignored.
    """
    token_fn = identity_toolkit_token if get_token is None else get_token
    url_fn = urlopen if open_url is None else open_url
    fix = "store FACEBOOK_APP_ID/FACEBOOK_APP_SECRET (scripts/human/meta/create-app-credentials.sh), then run make infra-gcp-apply"

    console_url = providers_console_url(project)
    if not project:
        return False, f"Firebase project is not configured; open {console_url}"

    token = token_fn(account)
    if not token:
        return False, f"Could not access {PROVIDER_ID} via API; open {console_url}"

    url = f"{IDENTITY_TOOLKIT_BASE}/{project}/defaultSupportedIdpConfigs/{PROVIDER_ID}"
    headers = {"Authorization": f"Bearer {token}", "x-goog-user-project": project}
    try:
        with url_fn(Request(url, headers=headers), timeout=20) as response:
            current = json.load(response)
    except HTTPError as error:
        code = error.code
        error.close()
        if code == 404:
            return False, f"{PROVIDER_ID} is disabled; {fix}"
        return False, f"Could not access {PROVIDER_ID} via API (HTTP {code}); open {console_url}"
    except (OSError, URLError, ValueError):
        return False, f"Could not access {PROVIDER_ID} via API; open {console_url}"
    if not isinstance(current, dict):
        return False, f"Could not access {PROVIDER_ID} via API; open {console_url}"
    current.pop("clientSecret", None)
    if current.get("enabled") is not True:
        return False, f"{PROVIDER_ID} is disabled; {fix}"
    if app_id and current.get("clientId") != app_id:
        return False, f"{PROVIDER_ID} uses a different app ID than FACEBOOK_APP_ID; run make infra-gcp-apply"
    return True, f"{PROVIDER_ID} is enabled"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project")
    parser.add_argument("--account", default=os.environ.get("GCLOUD_ACCOUNT"))
    parser.add_argument("--check", action="store_true", help="accepted for compatibility; always read-only")
    args = parser.parse_args(argv)

    app_id, _ = load_facebook_credentials(ROOT)
    ok, message = sync_facebook_provider(args.project, app_id, account=args.account)
    print(message)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
