#!/usr/bin/env python3
"""Rotate secrets: create new values only for what is asked, push them to every sink.

Usage:
  scripts/secrets/rotate.py NAME [NAME ...]   rotate the named secrets
  scripts/secrets/rotate.py --cheap           rotate every registry entry marked cheap
  scripts/secrets/rotate.py --list            show the registry

Any name works. Names missing from the registry are treated as manual secrets
pushed to the sinks given with --sink (default: github).

Generators (registry `generate`):
  random   new random value (`length`, `alphabet`: urlsafe | hex | alnum)
  command  stdout of `command` (run from the repo root)
  manual   value from env var NEW_<NAME>, otherwise a hidden prompt

Sinks (registry `sinks`):
  github   `gh secret set NAME` (value on stdin)
  env      NAME=value in the repo-root .env (created with mode 600)
  command  `sink_command` with the value on stdin and SECRET_NAME set

Cost (registry `cost`): `cheap` secrets have no side effects to regenerate and
are included by --cheap. `expensive` ones (provider resets, signing keys) are
only rotated when named explicitly, so nothing is regenerated redundantly.

Values are never printed or written anywhere except the configured sinks.
"""

from __future__ import annotations

import argparse
import getpass
import os
import secrets
import string
import subprocess
import sys
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = Path(__file__).with_name("registry.toml")
ALPHABETS = {
    "hex": string.hexdigits[:16],
    "alnum": string.ascii_letters + string.digits,
}
GENERATORS = {"random", "command", "manual"}
SINKS = {"github", "env", "command"}


@dataclass
class Secret:
    name: str
    generate: str = "manual"
    cost: str = "expensive"
    sinks: list[str] = field(default_factory=lambda: ["github"])
    length: int = 32
    alphabet: str = "urlsafe"
    command: str | None = None
    sink_command: str | None = None
    hint: str | None = None

    def validate(self) -> None:
        if self.generate not in GENERATORS:
            raise ValueError(f"{self.name}: unknown generator {self.generate!r}")
        if self.cost not in {"cheap", "expensive"}:
            raise ValueError(f"{self.name}: cost must be cheap or expensive")
        unknown = set(self.sinks) - SINKS
        if unknown:
            raise ValueError(f"{self.name}: unknown sinks {sorted(unknown)}")
        if self.generate == "command" and not self.command:
            raise ValueError(f"{self.name}: generate=command needs `command`")
        if "command" in self.sinks and not self.sink_command:
            raise ValueError(f"{self.name}: sink command needs `sink_command`")
        if self.alphabet not in {"urlsafe", *ALPHABETS}:
            raise ValueError(f"{self.name}: unknown alphabet {self.alphabet!r}")


def load_registry(path: Path = REGISTRY) -> dict[str, Secret]:
    if not path.exists():
        return {}
    data = tomllib.loads(path.read_text())
    registry = {}
    for name, entry in data.get("secrets", {}).items():
        secret = Secret(name=name, **entry)
        secret.validate()
        registry[name] = secret
    return registry


def generate(secret: Secret, *, env=os.environ, prompt=getpass.getpass) -> str:
    if secret.generate == "random":
        if secret.alphabet == "urlsafe":
            return secrets.token_urlsafe(secret.length)[: secret.length]
        alphabet = ALPHABETS[secret.alphabet]
        return "".join(secrets.choice(alphabet) for _ in range(secret.length))
    if secret.generate == "command":
        result = subprocess.run(
            secret.command, shell=True, cwd=ROOT, check=True, capture_output=True, text=True
        )
        value = result.stdout.strip()
    else:
        value = env.get(f"NEW_{secret.name}")
        if value is None:
            if secret.hint:
                print(f"{secret.name}: {secret.hint}", file=sys.stderr)
            value = prompt(f"New value for {secret.name}: ")
    if not value:
        raise ValueError(f"{secret.name}: empty value")
    return value


def write_env(name: str, value: str, path: Path) -> None:
    if "\n" in value:
        raise ValueError(f"{name}: multi-line values cannot go into .env")
    lines = path.read_text().splitlines() if path.exists() else []
    entry = f"{name}={value}"
    for index, line in enumerate(lines):
        if line.split("=", 1)[0].strip() == name:
            lines[index] = entry
            break
    else:
        lines.append(entry)
    path.touch(mode=0o600, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def push(secret: Secret, value: str, *, env_path: Path, run=subprocess.run) -> None:
    for sink in secret.sinks:
        if sink == "github":
            run(["gh", "secret", "set", secret.name], input=value, text=True, check=True)
        elif sink == "env":
            write_env(secret.name, value, env_path)
        elif sink == "command":
            run(
                secret.sink_command,
                shell=True,
                cwd=ROOT,
                input=value,
                text=True,
                check=True,
                env={**os.environ, "SECRET_NAME": secret.name},
            )


def select(registry: dict[str, Secret], names: list[str], cheap: bool, sinks: list[str]) -> list[Secret]:
    chosen: dict[str, Secret] = {}
    if cheap:
        chosen.update({n: s for n, s in registry.items() if s.cost == "cheap"})
    for name in names:
        if name not in registry:
            secret = Secret(name=name, sinks=sinks or ["github"])
            secret.validate()
            chosen[name] = secret
        else:
            chosen[name] = registry[name]
    return list(chosen.values())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="*", help="secret names to rotate")
    parser.add_argument("--cheap", action="store_true", help="also rotate every cheap registry entry")
    parser.add_argument("--sink", action="append", default=[], choices=sorted(SINKS - {"command"}),
                        help="sinks for names not in the registry (repeatable)")
    parser.add_argument("--registry", type=Path, default=REGISTRY)
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    parser.add_argument("--dry-run", action="store_true", help="show what would rotate")
    parser.add_argument("--list", action="store_true", help="list registry entries")
    args = parser.parse_args(argv)

    registry = load_registry(args.registry)
    if args.list:
        for s in registry.values():
            print(f"{s.name:28} {s.cost:9} {s.generate:8} -> {', '.join(s.sinks)}")
        return 0

    selected = select(registry, args.names, args.cheap, args.sink)
    if not selected:
        parser.error("name at least one secret or pass --cheap")

    failed = []
    for secret in selected:
        label = f"{secret.name} ({secret.generate} -> {', '.join(secret.sinks)})"
        if args.dry_run:
            print(f"would rotate {label}")
            continue
        try:
            push(secret, generate(secret), env_path=args.env_file)
            print(f"rotated {label}")
        except (subprocess.CalledProcessError, ValueError, OSError) as error:
            failed.append(secret.name)
            print(f"failed {secret.name}: {error}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
