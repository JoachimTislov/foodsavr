"""Per-clone instance state (ADR 0008): the gitignored `.agents/instance.local.json`.

The repository is stateless: project ids, buckets and billing accounts live
here (local tools), in GitHub Actions variables (CI) or in environment
variables, never in tracked files. Every worktree reads the main checkout's
file, so `make setup` writes it once per clone.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path
from typing import Any, Mapping

RELATIVE = Path(".agents/instance.local.json")


def main_checkout(root: Path) -> Path | None:
    """The main worktree of the clone containing `root` (None outside git)."""
    try:
        result = subprocess.run(["git", "-C", str(root), "rev-parse", "--path-format=absolute", "--git-common-dir"],
                                capture_output=True, text=True, timeout=10, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    common = result.stdout.strip()
    return Path(common).parent if result.returncode == 0 and common else None


def path(root: Path) -> Path:
    """FOODSAVR_INSTANCE_LOCAL, else this worktree's file when it has one, else the main checkout's."""
    override = os.environ.get("FOODSAVR_INSTANCE_LOCAL")
    if override:
        return Path(override).expanduser()
    own = root / RELATIVE
    if own.is_file():
        return own
    main = main_checkout(root)
    return main / RELATIVE if main else own


def load(root: Path) -> dict[str, Any]:
    try:
        data = json.loads(path(root).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def section(root: Path, name: str, environ: Mapping[str, str], env_keys: Mapping[str, str]) -> dict[str, Any]:
    """`name` section of the local file, overridden per key by non-empty environment variables."""
    found = load(root).get(name)
    values = dict(found) if isinstance(found, dict) else {}
    for key, variable in env_keys.items():
        if (environ.get(variable) or "").strip():
            values[key] = environ[variable].strip()
    return values


def deploy_overlay(root: Path, environ: Mapping[str, str] | None = None) -> dict[str, Any]:
    """Instance overlay of deploy/instance.yaml: DEPLOY_INSTANCE (JSON; CI) or local `deployInstance`."""
    environ = os.environ if environ is None else environ
    direct = (environ.get("DEPLOY_INSTANCE") or "").strip()
    if direct:
        try:
            data = json.loads(direct)
        except ValueError:
            return {}
        return data if isinstance(data, dict) else {}
    found = load(root).get("deployInstance")
    return found if isinstance(found, dict) else {}


def firebase_project(root: Path, environment: str = "test", environ: Mapping[str, str] | None = None) -> str:
    """FIREBASE_PROJECT(_ID), else the environment's project from the overlay; '' when unset."""
    environ = os.environ if environ is None else environ
    for variable in ("FIREBASE_PROJECT", "FIREBASE_PROJECT_ID"):
        if (environ.get(variable) or "").strip():
            return environ[variable].strip()
    env = (deploy_overlay(root, environ).get("environments") or {}).get(environment) or {}
    firebase = env.get("firebase") if isinstance(env, dict) else None
    return str((firebase or {}).get("projectId") or "") if isinstance(firebase, dict) else ""


def site_url(root: Path, environment: str = "test", channel: str | None = None,
             environ: Mapping[str, str] | None = None) -> str:
    """https URL of the environment's Hosting site (channel site when given); '' when unset."""
    env = (deploy_overlay(root, environ).get("environments") or {}).get(environment)
    env = env if isinstance(env, dict) else {}
    channels = env.get("channels") if isinstance(env.get("channels"), dict) else {}
    firebase = env.get("firebase") if isinstance(env.get("firebase"), dict) else {}
    site = (channels.get(channel) if channel else None) or firebase.get("siteId") or firebase_project(root, environment, environ)
    return f"https://{site}.web.app" if site else ""


def ci_variables(root: Path, environ: Mapping[str, str] | None = None) -> dict[str, str]:
    """Actions variables that publish this clone's instance state to CI."""
    found: dict[str, str] = {}
    overlay = deploy_overlay(root, environ)
    if overlay:
        found["DEPLOY_INSTANCE"] = json.dumps(overlay, sort_keys=True, separators=(",", ":"))
    defines = root / ".agents/state/firebase.defines.json"
    if not defines.is_file():
        main = main_checkout(root)
        defines = main / ".agents/state/firebase.defines.json" if main else defines
    try:
        data = json.loads(defines.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        data = None
    if isinstance(data, dict) and data:
        found["FIREBASE_DEFINES_TEST"] = json.dumps(data, sort_keys=True, separators=(",", ":"))
    return found


def _main(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Resolve instance values from env and local state (prints '' when unset).")
    parser.add_argument("what", choices=("firebase-project", "site-url", "path", "ci-variables"))
    parser.add_argument("--env", default="test", help="deployment environment (default: test)")
    parser.add_argument("--channel", help="release channel for site-url")
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    if args.what == "path":
        print(path(root))
    elif args.what == "ci-variables":
        print(json.dumps(ci_variables(root), sort_keys=True))
    elif args.what == "firebase-project":
        print(firebase_project(root, args.env))
    else:
        print(site_url(root, args.env, args.channel))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
