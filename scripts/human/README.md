# Human-only scripts

Interactive scripts for the setup steps that cannot be fully automated: browser consent, console clicks, downloaded keys, and two-factor prompts. You run them in a terminal; agents never execute them (CI and `agentctl` reject it) and point you here instead. Everything automatable stays in `scripts/secrets/rotate.py` generators or CI.

## Layout

`scripts/human/<domain>/<intent>-<area>.sh`

- **domain**: the system that owns the secret (`github`, `agents`, `firebase`, `codecov`, `android`, `meta`, `google`, ...).
- **intent**: one verb per script: `create`, `login`, `rotate`, `sync`, `revoke`, or `verify`.
- **area**: the specific resource, for example `agent-app` or `claude-runner`.

List them with `ls scripts/human/*/`. Each script's header names its intent, domain, area, the registry secrets it sets, and why it needs you.

## Rules for new scripts

1. Build from the wizard skill library (`.agents/skills/wizard/template.sh`, everything above `run_wizard() {`) and keep that library unedited.
2. Start the header with `# Intent:`, `# Domain:`, `# Area:`, `# Secrets:`, and `# Why human:`.
3. Make the first line inside `run_wizard` the interactive guard:
   `[[ -t 0 && -t 1 ]] || { echo "scripts/human: interactive only; run it yourself in a terminal" >&2; exit 2; }`
4. Store values only through `set_secret` (which calls `scripts/secrets/rotate.py`), and register every secret in `scripts/secrets/registry.toml` in the same change, with a hint that names the script.
5. Never print a value; `confirm` before anything irreversible.

`scripts/agents/test_agentctl.py` checks the layout, header, guard, and `bash -n` syntax of every script here.
