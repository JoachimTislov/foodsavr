#!/usr/bin/env python3
"""Rotate secrets: create new values only for what is asked, push them to every sink.

Usage:
  scripts/secrets/rotate.py NAME [NAME ...]   rotate the named registry secrets
  scripts/secrets/rotate.py NEW --sink env    rotate an unregistered secret (needs --sink)
  scripts/secrets/rotate.py --low-effort      rotate every low-effort registry entry
  scripts/secrets/rotate.py --group firebase  rotate a whole group after a leak (also: @firebase)
  scripts/secrets/rotate.py --list            show the registry

Names must match [A-Z_][A-Z0-9_]*. Unregistered names are refused unless --sink
is given, so a typo never creates a new secret; register new secrets instead.

Generators (registry `generate`):
  random   new random value (`length`, `alphabet`: urlsafe | hex | alnum)
  command  stdout of `command` (run from the repo root); must mint a new value
  sync     stdout of `command` mirroring a source file; reported as "synced",
           since the value only changes when its source changes
  manual   value from env var NEW_<NAME>, otherwise a hidden prompt (TTY only)

Sinks (registry `sinks`):
  github   `gh secret set NAME` (value on stdin)
  env      NAME='value' in the repo-root .env (written atomically, mode 600)
  command  `sink_command` with the value on stdin and SECRET_NAME set

Effort (registry `effort`): how complex or time-consuming renewal is, never
how bad a leak would be. `low` renews automatically and is included by
--low-effort for routine rotation; `high` needs manual provider steps and is
only rotated when named or grouped, so nothing is regenerated redundantly.

Any leak means rotation, whatever the effort. Groups (registry `groups`) are
secrets stored close together, so one leak exposes them all: `--group NAME` /
`@NAME` rotates every member without asking, high-effort ones included.

Public values (registry `public = true`) are shipped in clients by design, such
as a bundled .env or Firebase client config. Being visible there is not a leak,
so groups and --low-effort skip them; they rotate only when named.

Values are never printed or written anywhere except the configured sinks.
"""

from __future__ import annotations

import argparse
import dataclasses
import getpass
import os
import re
import secrets
import string
import subprocess
import sys
import tempfile
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = Path(__file__).with_name("registry.toml")
NAME_PATTERN = re.compile(r"[A-Z_][A-Z0-9_]*")
ALPHABETS = {
    "hex": string.hexdigits[:16],
    "alnum": string.ascii_letters + string.digits,
}
GENERATORS = {"random", "command", "sync", "manual"}
SINKS = {"github", "env", "command"}


@dataclass
class Secret:
    name: str
    generate: str = "manual"
    effort: str = "high"
    public: bool = False
    sinks: list[str] = field(default_factory=lambda: ["github"])
    length: int = 32
    alphabet: str = "urlsafe"
    command: str | None = None
    sink_command: str | None = None
    hint: str | None = None
    groups: list[str] = field(default_factory=list)

    def validate(self) -> None:
        if not NAME_PATTERN.fullmatch(self.name):
            raise ValueError(f"{self.name!r}: names must match {NAME_PATTERN.pattern}")
        if self.generate not in GENERATORS:
            raise ValueError(f"{self.name}: unknown generator {self.generate!r}")
        if self.effort not in {"low", "high"}:
            raise ValueError(f"{self.name}: effort must be low or high")
        unknown = set(self.sinks) - SINKS
        if unknown:
            raise ValueError(f"{self.name}: unknown sinks {sorted(unknown)}")
        if self.generate in {"command", "sync"} and not self.command:
            raise ValueError(f"{self.name}: generate={self.generate} needs `command`")
        if "command" in self.sinks and not self.sink_command:
            raise ValueError(f"{self.name}: sink command needs `sink_command`")
        if self.alphabet not in {"urlsafe", *ALPHABETS}:
            raise ValueError(f"{self.name}: unknown alphabet {self.alphabet!r}")


FIELD_TYPES = {
    "generate": str,
    "effort": str,
    "public": bool,
    "sinks": list,
    "length": int,
    "alphabet": str,
    "command": str,
    "sink_command": str,
    "hint": str,
    "groups": list,
}


def parse_entry(name: str, entry: object) -> Secret:
    if not isinstance(entry, dict):
        raise ValueError(f"{name}: entry must be a table")
    unknown = set(entry) - {f.name for f in dataclasses.fields(Secret)} | ({"name"} & set(entry))
    if unknown:
        raise ValueError(f"{name}: unknown keys {sorted(unknown)}")
    for key, value in entry.items():
        expected = FIELD_TYPES[key]
        if not isinstance(value, expected) or (expected is int and isinstance(value, bool)):
            raise ValueError(f"{name}: {key} must be {expected.__name__}")
        if expected is list and not all(isinstance(item, str) for item in value):
            raise ValueError(f"{name}: {key} must be a list of strings")
    secret = Secret(name=name, **entry)
    secret.validate()
    return secret


def load_registry(path: Path = REGISTRY) -> dict[str, Secret]:
    if not path.exists():
        return {}
    try:
        data = tomllib.loads(path.read_text())
    except tomllib.TOMLDecodeError as error:
        raise ValueError(f"{path}: {error}") from error
    return {name: parse_entry(name, entry) for name, entry in data.get("secrets", {}).items()}


def generate(secret: Secret, *, env=os.environ, prompt=getpass.getpass, interactive=None) -> str:
    if secret.generate == "random":
        if secret.alphabet == "urlsafe":
            return secrets.token_urlsafe(secret.length)[: secret.length]
        alphabet = ALPHABETS[secret.alphabet]
        return "".join(secrets.choice(alphabet) for _ in range(secret.length))
    if secret.generate in {"command", "sync"}:
        result = subprocess.run(
            secret.command, shell=True, cwd=ROOT, check=True, capture_output=True, text=True
        )
        value = result.stdout.strip()
    else:
        value = env.get(f"NEW_{secret.name}")
        if value is None:
            if interactive is None:
                interactive = sys.stdin.isatty()
            if not interactive:
                raise ValueError(f"{secret.name}: no TTY; set NEW_{secret.name}")
            if secret.hint:
                print(f"{secret.name}: {secret.hint}", file=sys.stderr)
            value = prompt(f"New value for {secret.name}: ")
    if not value:
        raise ValueError(f"{secret.name}: empty value")
    return value


def write_env(name: str, value: str, path: Path) -> None:
    if any(char in value for char in "\n\r'"):
        raise ValueError(f"{name}: .env values cannot contain newlines or single quotes")
    lines = path.read_text().splitlines() if path.exists() else []
    entry = f"{name}='{value}'"
    key = re.compile(rf"\s*(export\s+)?{re.escape(name)}\s*=")
    for index, line in enumerate(lines):
        if key.match(line):
            lines[index] = entry
            break
    else:
        lines.append(entry)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".env.")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as handle:
            handle.write("\n".join(lines) + "\n")
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


class PushError(Exception):
    def __init__(self, done: list[str], sink: str, error: Exception):
        self.done, self.sink, self.error = done, sink, error
        live = f"; already updated: {', '.join(done)}" if done else ""
        super().__init__(f"sink {sink} failed ({error}){live}; old value still live there and in later sinks")


def push(secret: Secret, value: str, *, env_path: Path, run=subprocess.run) -> None:
    done: list[str] = []
    for sink in secret.sinks:
        try:
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
        except (subprocess.CalledProcessError, ValueError, OSError) as error:
            raise PushError(done, sink, error) from error
        done.append(sink)


def group_names(registry: dict[str, Secret]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {}
    for secret in registry.values():
        for group in secret.groups:
            groups.setdefault(group, []).append(secret.name)
    return groups


def select(
    registry: dict[str, Secret],
    names: list[str],
    low_effort: bool,
    sinks: list[str],
    groups: list[str] = (),
) -> list[Secret]:
    chosen: dict[str, Secret] = {}
    known_groups = group_names(registry)
    groups = list(groups) + [n[1:] for n in names if n.startswith("@")]
    names = [n for n in names if not n.startswith("@")]
    for group in groups:
        if group not in known_groups:
            raise ValueError(f"unknown group {group!r}; known: {sorted(known_groups)}")
        members = {n: registry[n] for n in known_groups[group] if not registry[n].public}
        if not members:
            raise ValueError(f"group {group!r} has only public members; name them to rotate")
        chosen.update(members)
    if low_effort:
        chosen.update({n: s for n, s in registry.items() if s.effort == "low" and not s.public})
    for name in names:
        if name in registry:
            if sinks:
                raise ValueError(f"{name} is registered; --sink only applies to unregistered names")
            chosen[name] = registry[name]
        elif not sinks:
            raise ValueError(f"{name} is not in the registry; register it or pass --sink")
        else:
            secret = Secret(name=name, sinks=sinks)
            secret.validate()
            chosen[name] = secret
    return list(chosen.values())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="*", help="secret names (or @group) to rotate")
    parser.add_argument("--low-effort", action="store_true", help="also rotate every low-effort registry entry")
    parser.add_argument("--group", action="append", default=[],
                        help="rotate every non-public member of a group after a leak (repeatable)")
    parser.add_argument("--sink", action="append", default=[], choices=sorted(SINKS - {"command"}),
                        help="sinks for unregistered names (repeatable; required for them)")
    parser.add_argument("--registry", type=Path, default=REGISTRY)
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    parser.add_argument("--dry-run", action="store_true", help="show what would rotate")
    parser.add_argument("--list", action="store_true", help="list registry entries")
    args = parser.parse_args(argv)

    try:
        registry = load_registry(args.registry)
        if args.list:
            for s in registry.values():
                groups = f"  [{', '.join(s.groups)}]" if s.groups else ""
                effort = "public" if s.public else f"{s.effort}-effort"
                print(f"{s.name:28} {effort:12} {s.generate:8} -> {', '.join(s.sinks)}{groups}")
            return 0
        selected = select(registry, args.names, args.low_effort, args.sink, args.group)
    except ValueError as error:
        parser.error(str(error))
    if not selected:
        parser.error("name at least one secret, group, or pass --low-effort")

    manual = [s.name for s in selected if s.effort == "high"]
    if manual and not args.dry_run:
        print(f"High-effort renewals (manual provider steps): {', '.join(manual)}", file=sys.stderr)

    failed = []
    for secret in selected:
        label = f"{secret.name} ({secret.generate} -> {', '.join(secret.sinks)})"
        verb = "sync" if secret.generate == "sync" else "rotate"
        if args.dry_run:
            print(f"would {verb} {label}")
            continue
        try:
            push(secret, generate(secret), env_path=args.env_file)
            if secret.generate == "sync":
                print(f"synced {label}; not rotated: change its source to rotate it")
            else:
                print(f"rotated {label}")
        except (PushError, subprocess.CalledProcessError, ValueError, OSError, EOFError) as error:
            failed.append(secret.name)
            print(f"failed {secret.name}: {error}", file=sys.stderr)
        except KeyboardInterrupt:
            failed.append(secret.name)
            print(f"interrupted at {secret.name}", file=sys.stderr)
            break
    if failed:
        print(f"failed: {', '.join(failed)}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
