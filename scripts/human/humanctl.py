#!/usr/bin/env python3
"""`make human`: one menu for every manual process and pipeline bypass.

The menu has two sources and nothing else, so it cannot go stale:
  * scripts/human/menu.toml    make targets (setup, infra, secrets, every bypass)
  * scripts/human/<domain>/*.sh  discovered from their headers

  humanctl.py --list    plain text menu (agents, docs; no terminal needed)
  humanctl.py           interactive menu (terminal only, like scripts/human/*.sh)
  humanctl.py --check   verify that every entry resolves to a make target or script
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
import subprocess
import sys
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HUMAN = ROOT / "scripts/human"
MENU = HUMAN / "menu.toml"
BYPASS_MK = ROOT / "make/bypass.mk"
GUARD_MESSAGE = "scripts/human: interactive only; run it yourself in a terminal (`make human LIST=1` prints the menu)"


@dataclass(frozen=True)
class Var:
    name: str
    prompt: str
    required: bool = False
    default: str = ""
    choices: tuple[str, ...] = ()


@dataclass(frozen=True)
class Entry:
    id: str
    group: str
    title: str
    kind: str  # make | script
    target: str  # make target, or script path relative to the repository root
    step: str = ""
    needs: str = ""
    vars: tuple[Var, ...] = ()
    dry_assign: str = ""
    apply_assign: str = ""
    args: str = ""


@dataclass
class Registry:
    groups: list[tuple[str, str]]
    entries: list[Entry]
    excluded: list[str] = field(default_factory=list)


def load_registry(path: Path = MENU) -> Registry:
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    groups = [(g["id"], g["title"]) for g in data.get("group", [])]
    entries = []
    for raw in data.get("entry", []):
        entries.append(
            Entry(
                id=raw["id"], group=raw["group"], title=raw["title"],
                kind="script" if "script" in raw else "make", target=raw.get("script") or raw["target"],
                args=raw.get("args", ""),
                step=raw.get("step", ""), needs=raw.get("needs", ""),
                vars=tuple(
                    Var(v["name"], v.get("prompt", v["name"]), bool(v.get("required", False)),
                        v.get("default", ""), tuple(v.get("choices", ())))
                    for v in raw.get("vars", [])
                ),
                dry_assign=raw.get("dry_assign", ""), apply_assign=raw.get("apply_assign", ""),
            )
        )
    return Registry(groups, entries, list(data.get("excluded", [])))


def script_header(text: str) -> dict[str, str]:
    """`# Key: value` lines of a script's leading comment block, with `#   ` continuations."""
    fields: dict[str, str] = {}
    current = ""
    for line in text.splitlines()[:40]:
        if not line.startswith("#"):
            if fields:
                break
            continue
        match = re.match(r"^# (Intent|Domain|Area|Secrets|Why human):\s*(.*)$", line)
        if match:
            current = match.group(1)
            fields[current] = match.group(2).strip()
        elif current and re.match(r"^#\s{2,}\S", line):
            fields[current] += " " + line[1:].strip()
        else:
            current = ""
    return fields


def discover_scripts(human: Path = HUMAN, root: Path = ROOT) -> list[Entry]:
    entries = []
    for script in sorted(human.glob("*/*.sh")):
        header = script_header(script.read_text(encoding="utf-8"))
        domain = script.parent.name
        name = script.stem
        intent = header.get("Intent") or name.split("-", 1)[0]
        area = header.get("Area") or name.split("-", 1)[-1]
        entries.append(
            Entry(
                id=f"{domain}/{name}", group="scripts", kind="script",
                title=f"{intent.capitalize()} {domain} {area}".replace("-", " "),
                target=script.relative_to(root).as_posix(),
                needs=header.get("Why human", ""),
            )
        )
    return entries


def all_entries(registry: Registry | None = None) -> list[Entry]:
    registry = registry or load_registry()
    return [*registry.entries, *discover_scripts()]


def command(entry: Entry, values: dict[str, str], extra: tuple[str, ...] = ()) -> list[str]:
    """Argv that runs an entry: `make <target> VAR=value ...` or `bash <script>`."""
    if entry.kind == "script":
        return ["bash", entry.target, *shlex.split(entry.args)]
    assignments = [f"{k}={v}" for k, v in values.items() if v != ""]
    return ["make", entry.target, *assignments, *extra]


def render_list(registry: Registry, entries: list[Entry]) -> str:
    lines = ["Manual processes and pipeline bypasses (run `make human` for the interactive menu)", ""]
    width = max((len(e.id) for e in entries), default=0) + 2
    for group_id, title in registry.groups:
        members = [e for e in entries if e.group == group_id]
        if not members:
            continue
        lines.append(title)
        for entry in members:
            if entry.kind == "script":
                usage = " ".join(["bash", entry.target, entry.args]).strip()
            else:
                args = " ".join(
                    f"{v.name}=<{'|'.join(v.choices) or v.name.lower()}>" if v.required else f"[{v.name}=...]"
                    for v in entry.vars
                )
                usage = f"make {entry.target}{' ' + args if args else ''}"
                flag = entry.apply_assign if entry.apply_assign.split("=", 1)[-1] else entry.dry_assign
                if flag:
                    usage += f" [{flag}]"
            lines.append(f"  {entry.id:<{width}}{entry.title}")
            lines.append(f"  {'':<{width}}{usage}")
            label = "why you" if entry.kind == "script" else "needs"
            detail = [f"bypasses {entry.step}" if entry.step else "", f"{label}: {entry.needs}" if entry.needs else ""]
            lines.append(f"  {'':<{width}}{'; '.join(d for d in detail if d)}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


# --- consistency checks (used by the tests and `--check`) --------------------


def make_targets(root: Path = ROOT) -> set[str]:
    """Explicit targets of the Makefile (the catch-all `%` rule in github.mk is not one)."""
    out = subprocess.run(["make", "-qp", "-f", "Makefile", "--no-print-directory"], cwd=root, capture_output=True, text=True)
    targets: set[str] = set()
    previous = ""
    for line in out.stdout.splitlines():
        match = re.match(r"^([A-Za-z0-9][A-Za-z0-9_.+-]*)\s*:(?!=)", line)
        if match and previous != "# Not a target:":
            targets.add(match.group(1))
        previous = line
    return targets


def declared_bypass_targets(path: Path = BYPASS_MK) -> list[str]:
    match = re.search(r"^\.PHONY:\s*(.+)$", path.read_text(encoding="utf-8"), re.MULTILINE)
    return match.group(1).split() if match else []


def check_entries(registry: Registry, entries: list[Entry], targets: set[str], root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    group_ids = {g for g, _ in registry.groups}
    seen: set[str] = set()
    for entry in entries:
        if entry.id in seen:
            errors.append(f"duplicate id {entry.id}")
        seen.add(entry.id)
        if entry.group not in group_ids:
            errors.append(f"{entry.id}: unknown group {entry.group}")
        if entry.kind == "make" and entry.target not in targets:
            errors.append(f"{entry.id}: make target '{entry.target}' does not exist")
        if entry.kind == "script":
            script = root / entry.target
            if not script.is_file():
                errors.append(f"{entry.id}: script {entry.target} does not exist")
            elif not script.stat().st_mode & 0o111:
                errors.append(f"{entry.id}: script {entry.target} is not executable")
    listed = {e.target for e in entries if e.kind == "make"}
    for target in declared_bypass_targets():
        if target not in listed and target not in registry.excluded:
            errors.append(f"make/bypass.mk target '{target}' is not in scripts/human/menu.toml")
    return errors


# --- status and the interactive menu -----------------------------------------


def capture(cmd: list[str], timeout: int = 90) -> str | None:
    try:
        out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return out.stdout if out.stdout.strip() else None


def status_lines(profile: str = "full-cloud") -> list[str]:
    """What is missing, from `setupctl verify` and `agentctl status` (the tools that know)."""
    lines: list[str] = []
    verify = capture(["python3", "scripts/setup/setupctl.py", "verify", "--profile", profile, "-o", "json"])
    if verify:
        try:
            for check in json.loads(verify).get("checks", []):
                if not check.get("ok"):
                    lines.append(f"setup: {check['name']}: {check['detail']} -> {check['remediation']}")
        except ValueError:
            lines.append("setup: could not read `setupctl verify` output")
    status = capture(["scripts/agents/agentctl", "status", "-o", "json"])
    if status:
        try:
            for item in json.loads(status).get("status", {}).get("reconcile", {}).get("owner", []):
                lines.append(f"owner: {item['component']}: {item['action']}")
        except (ValueError, AttributeError):
            lines.append("owner: could not read `agentctl status` output")
    return lines


def ask(prompt: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    reply = input(f"  {prompt}{suffix}: ").strip()
    return reply or default


def collect(entry: Entry) -> dict[str, str] | None:
    values: dict[str, str] = {}
    for var in entry.vars:
        label = f"{var.prompt} ({'/'.join(var.choices)})" if var.choices else var.prompt
        while True:
            value = ask(label, var.default)
            if var.choices and value and value not in var.choices:
                print(f"  choose one of: {', '.join(var.choices)}")
                continue
            if var.required and not value:
                if ask("Required. Cancel this entry? [y/N]").lower().startswith("y"):
                    return None
                continue
            values[var.name] = value
            break
    return values


def run_entry(entry: Entry) -> None:
    values = collect(entry)
    if values is None:
        return
    extra = tuple(entry.dry_assign.split()) if entry.dry_assign else ()
    cmd = command(entry, values, extra)
    print(f"\n  $ {shlex.join(cmd)}\n", flush=True)
    code = subprocess.run(cmd, cwd=ROOT).returncode
    if code == 0 and entry.apply_assign:
        label = "Applied only after your yes"
        if ask(f"{label}. Run it for real with {entry.apply_assign}? [y/N]").lower().startswith("y"):
            cmd = command(entry, {**values, **dict(a.split("=", 1) for a in entry.apply_assign.split())})
            print(f"\n  $ {shlex.join(cmd)}\n", flush=True)
            code = subprocess.run(cmd, cwd=ROOT).returncode
    print(f"\n  exit {code}")


def interactive() -> int:
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        print(GUARD_MESSAGE, file=sys.stderr)
        return 2
    registry = load_registry()
    entries = all_entries(registry)
    print("\n  Checking what is missing (setup verify, agent status)...", flush=True)
    missing = status_lines()
    while True:
        print("\033[2J\033[H", end="")
        print("\n  FoodSavr: manual processes and pipeline bypasses\n")
        if missing:
            print("  Missing or needing you:")
            for line in missing:
                print(f"    - {line}")
        else:
            print("  Nothing reported missing.")
        print()
        numbered: list[Entry] = []
        for group_id, title in registry.groups:
            members = [e for e in entries if e.group == group_id]
            if not members:
                continue
            print(f"  {title}")
            for entry in members:
                numbered.append(entry)
                note = f"  [bypasses {entry.step}]" if entry.step else ""
                print(f"   {len(numbered):>2}) {entry.title}{note}")
            print()
        try:
            choice = input("  Number, id, r to refresh status, q to quit: ").strip()
        except EOFError:
            return 0
        if choice in {"q", "quit", ""}:
            return 0
        if choice == "r":
            missing = status_lines()
            continue
        chosen = next((e for i, e in enumerate(numbered, 1) if choice in {str(i), e.id}), None)
        if chosen is None:
            input("  Unknown choice. Press Enter.")
            continue
        run_entry(chosen)
        input("\n  Press Enter to return to the menu.")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--list", action="store_true", help="print the menu as plain text")
    parser.add_argument("--check", action="store_true", help="verify every entry resolves; exit 1 on problems")
    args = parser.parse_args(argv)
    registry = load_registry()
    entries = all_entries(registry)
    if args.check:
        errors = check_entries(registry, entries, make_targets())
        print("\n".join(errors) if errors else f"{len(entries)} menu entries resolve.")
        return 1 if errors else 0
    if args.list:
        print(render_list(registry, entries), end="")
        return 0
    return interactive()


if __name__ == "__main__":
    sys.exit(main())
