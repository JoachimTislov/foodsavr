#!/usr/bin/env python3
"""Validate GitHub App PEM private keys locally and verify installation token minting."""

from __future__ import annotations

import argparse
import base64
from collections.abc import Callable
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

try:
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import padding, rsa
    from cryptography.hazmat.primitives.serialization import load_pem_private_key

    HAS_CRYPTOGRAPHY = True
except ImportError:
    HAS_CRYPTOGRAPHY = False

PKCS1_BEGIN = "-----BEGIN RSA PRIVATE KEY-----"
PKCS1_END = "-----END RSA PRIVATE KEY-----"
PKCS8_BEGIN = "-----BEGIN PRIVATE KEY-----"
PKCS8_END = "-----END PRIVATE KEY-----"
PEM_PAIRS = {
    PKCS1_BEGIN: PKCS1_END,
    PKCS8_BEGIN: PKCS8_END,
}
APP_SETTINGS_URL = "https://github.com/settings/apps"


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _validate_with_cryptography(pem_bytes: bytes) -> None:
    try:
        key = load_pem_private_key(pem_bytes, password=None)
    except (TypeError, ValueError) as exc:
        raise ValueError("GitHub App private key could not be parsed as an unencrypted PEM RSA private key.") from exc
    if not isinstance(key, rsa.RSAPrivateKey):
        raise ValueError("GitHub App private key must be an RSA private key.")


def _validate_with_openssl(pem_bytes: bytes) -> None:
    try:
        pkey = subprocess.run(
            ["openssl", "pkey", "-noout", "-inform", "PEM"],
            input=pem_bytes,
            capture_output=True,
            timeout=15,
            check=False,
        )
        if pkey.returncode != 0:
            raise ValueError("GitHub App private key could not be parsed as a valid PEM private key.")
        rsa_check = subprocess.run(
            ["openssl", "rsa", "-noout", "-check"],
            input=pem_bytes,
            capture_output=True,
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ValueError("Install OpenSSL or Python cryptography to validate GitHub App private keys.") from exc
    if rsa_check.returncode != 0:
        raise ValueError("GitHub App private key must be a valid unencrypted RSA private key.")


def validate(content: bytes | str) -> str:
    """Validate that *content* is a well-formed, unquoted, unescaped PEM RSA private key."""
    if isinstance(content, bytes):
        try:
            text = content.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ValueError("GitHub App private key must be UTF-8 PEM text.") from exc
    elif isinstance(content, str):
        text = content
    else:
        raise ValueError("GitHub App private key must be bytes or text.")

    if not text.strip():
        raise ValueError("GitHub App private key is empty.")
    if "\\n" in text or "\\r" in text:
        raise ValueError(
            "GitHub App private key contains literal \\n escapes instead of line breaks; pass the raw PEM file."
        )

    normalized = text.replace("\r\n", "\n").replace("\r", "\n").strip()
    if (normalized[0] in ("'", '"') and normalized[-1] in ("'", '"')) or any(
        line.strip().startswith(("'", '"')) or line.strip().endswith(("'", '"'))
        for line in normalized.splitlines()
        if line.strip()
    ):
        raise ValueError("GitHub App private key contains stray quotes; pass the unquoted PEM contents.")

    if "ENCRYPTED" in normalized:
        raise ValueError("GitHub App private key must be unencrypted.")

    lines = [line.strip() for line in normalized.splitlines() if line.strip()]
    if len(lines) < 3 or lines[0] not in PEM_PAIRS:
        raise ValueError(
            "GitHub App private key must start with -----BEGIN RSA PRIVATE KEY----- or -----BEGIN PRIVATE KEY-----."
        )
    expected_end = PEM_PAIRS[lines[0]]
    if lines[-1] != expected_end:
        raise ValueError(f"GitHub App private key is truncated or missing {expected_end}.")
    if any(line.startswith("-----BEGIN ") or line.startswith("-----END ") for line in lines[1:-1]):
        raise ValueError("GitHub App private key must contain a single PEM private key block.")

    body = lines[1:-1]
    if not body or not all(re.fullmatch(r"[A-Za-z0-9+/=]+", line) for line in body):
        raise ValueError("GitHub App private key contains invalid base64 body characters.")

    canonical = "\n".join(lines) + "\n"
    pem_bytes = canonical.encode("utf-8")
    if HAS_CRYPTOGRAPHY:
        _validate_with_cryptography(pem_bytes)
    else:
        _validate_with_openssl(pem_bytes)
    return canonical


def _sign_rs256_cryptography(pem_bytes: bytes, signing_input: bytes) -> bytes:
    key = load_pem_private_key(pem_bytes, password=None)
    assert isinstance(key, rsa.RSAPrivateKey)
    return key.sign(signing_input, padding.PKCS1v15(), hashes.SHA256())


def _sign_rs256_openssl(pem_bytes: bytes, signing_input: bytes) -> bytes:
    r_fd, w_fd = os.pipe()
    try:
        os.write(w_fd, pem_bytes)
    finally:
        os.close(w_fd)
    try:
        proc = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", f"/dev/fd/{r_fd}"],
            input=signing_input,
            capture_output=True,
            pass_fds=(r_fd,),
            timeout=15,
            check=False,
        )
    finally:
        os.close(r_fd)
    if proc.returncode != 0 or not proc.stdout:
        raise ValueError("Failed signing GitHub App JWT with OpenSSL.")
    return proc.stdout


def mint_app_jwt(app_id: str | int, pem: bytes | str, *, now: int | None = None) -> str:
    """Create a short-lived RS256 JWT for authenticating as a GitHub App."""
    app_id_str = str(app_id).strip()
    if not re.fullmatch(r"\d+", app_id_str):
        raise ValueError(f"Invalid GitHub App ID: {app_id!r}")
    canonical = validate(pem)
    ts = int(time.time()) if now is None else int(now)
    header = _b64url(json.dumps({"alg": "RS256", "typ": "JWT"}, separators=(",", ":")).encode("utf-8"))
    payload = _b64url(
        json.dumps({"iat": ts - 60, "exp": ts + 300, "iss": app_id_str}, separators=(",", ":")).encode("utf-8")
    )
    signing_input = f"{header}.{payload}".encode("ascii")
    pem_bytes = canonical.encode("utf-8")
    if HAS_CRYPTOGRAPHY:
        sig = _sign_rs256_cryptography(pem_bytes, signing_input)
    else:
        sig = _sign_rs256_openssl(pem_bytes, signing_input)
    return f"{header}.{payload}.{_b64url(sig)}"


def verify_installation_token(
    pem: bytes | str,
    *,
    app_id: str | int | None,
    repo: str | None = None,
    installation_id: int | str | None = None,
    open_url: Callable[..., Any] | None = None,
) -> tuple[bool, str]:
    """Verify a GitHub App key for either a repository or an explicit installation."""
    if repo and installation_id is not None:
        return False, "Choose either a GitHub repository or an installation ID to verify."
    install_url = f"https://github.com/{repo}/settings/installations" if repo else APP_SETTINGS_URL
    vars_url = f"https://github.com/{repo}/settings/variables/actions" if repo else APP_SETTINGS_URL
    try:
        canonical = validate(pem)
    except ValueError as exc:
        return False, f"{exc} Generate a valid key at {APP_SETTINGS_URL} and re-run."

    app_id_str = "" if app_id is None else str(app_id).strip()
    if not re.fullmatch(r"\d+", app_id_str):
        return False, f"GitHub App ID is missing or invalid; set it at {vars_url} and re-run."

    try:
        jwt_token = mint_app_jwt(app_id_str, canonical)
    except ValueError as exc:
        return False, f"{exc} Generate a valid key at {APP_SETTINGS_URL} and re-run."

    url_fn = urlopen if open_url is None else open_url
    headers = {
        "Authorization": f"Bearer {jwt_token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "foodsavr-setup",
    }

    inst_id: str | None = str(installation_id).strip() if installation_id is not None else None
    if not inst_id:
        lookup_url = (
            f"https://api.github.com/repos/{repo}/installation"
            if repo
            else "https://api.github.com/app/installations?per_page=1"
        )
        try:
            with url_fn(Request(lookup_url, headers=headers), timeout=20) as resp:
                data = json.load(resp)
        except HTTPError as err:
            code = err.code
            err.close()
            if code == 401:
                return False, f"Private key rejected for App {app_id_str}; generate a new key at {APP_SETTINGS_URL} and re-sync."
            if code == 404:
                return False, f"App {app_id_str} is not installed; install it at {install_url} and re-run."
            return False, f"Could not look up App {app_id_str} installation (HTTP {code}); check {install_url}."
        except (OSError, URLError, ValueError):
            return False, f"Could not reach GitHub API to verify App {app_id_str}; check {install_url} and re-run."

        if repo:
            inst_id = str(data.get("id", "")) if isinstance(data, dict) else ""
        elif isinstance(data, list) and data and isinstance(data[0], dict):
            inst_id = str(data[0].get("id", ""))
        if not inst_id:
            return False, f"App {app_id_str} has no active installation; install it at {install_url} and re-run."

    token_url = f"https://api.github.com/app/installations/{inst_id}/access_tokens"
    post_headers = {**headers, "Content-Type": "application/json"}
    try:
        with url_fn(Request(token_url, data=b"{}", headers=post_headers, method="POST"), timeout=20) as resp:
            token_data = json.load(resp)
    except HTTPError as err:
        code = err.code
        err.close()
        if code == 401:
            return False, f"Private key rejected for App {app_id_str}; generate a new key at {APP_SETTINGS_URL} and re-sync."
        return False, f"App {app_id_str} failed to mint an installation token (HTTP {code}); check {install_url}."
    except (OSError, URLError, ValueError):
        return False, f"Could not reach GitHub API to mint a token for App {app_id_str}; check {install_url}."

    if not isinstance(token_data, dict) or not isinstance(token_data.get("token"), str) or not token_data["token"]:
        return False, f"GitHub API did not return an installation token for App {app_id_str}; check {install_url}."

    target = f" on {repo}" if repo else f" for installation {inst_id}"
    return True, f"Verified GitHub App {app_id_str}{target} (installation token minted)."


def _read_input(path: Path) -> bytes:
    if str(path) == "-":
        return sys.stdin.buffer.read()
    return path.read_bytes()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_val = sub.add_parser("validate", help="Validate a PEM RSA private key locally")
    p_val.add_argument("path", type=Path, help="Path to PEM file, or - for stdin")

    p_ver = sub.add_parser("verify", help="Verify a PEM key by minting a GitHub App installation token")
    p_ver.add_argument("path", type=Path, help="Path to PEM file, or - for stdin")
    p_ver.add_argument("--app-id", required=True)
    target = p_ver.add_mutually_exclusive_group()
    target.add_argument("--repo", default=None)
    target.add_argument("--installation-id", default=None)

    args = parser.parse_args(argv)
    try:
        raw = _read_input(args.path)
    except OSError as exc:
        print(f"Cannot read private key file: {exc}", file=sys.stderr)
        return 1

    if args.command == "validate":
        try:
            validate(raw)
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        return 0

    ok, message = verify_installation_token(
        raw,
        app_id=args.app_id,
        repo=args.repo,
        installation_id=args.installation_id,
    )
    print(message, file=sys.stdout if ok else sys.stderr)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
