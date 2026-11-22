#!/usr/bin/env bash
# Idempotent setup and audit for FoodSavr web monitoring and the autonomous healing loop.
#
# Usage:
#   scripts/setup/monitoring.sh [--check] [--no-interactive] [--repo <owner/name>]
#                               [--plan <spark|blaze>]
#                               [--auto-heal <true|false>]
#                               [--auto-heal-merge <true|false>]
#                               [--telemetry-poll <true|false>]
#                               [--target-url <https://...>]
#                               [--error-reporter <none|spark-firestore|crashlytics-web|external>]
#                               [--error-collector-endpoint <https://...>]
#
# Modes:
#   --check          Non-mutating audit of required GitHub secrets, repository
#                    variables, monitoring workflows, and local probe tooling.
#   (default)        Audits prerequisites, guides/launches human secret wizards
#                    when interactive on a TTY, and configures GitHub repository
#                    variables via `gh variable set`.
#
# Human-only secret wizards (interactive terminal required):
#   scripts/human/agents/login-claude-runner.sh   (CLAUDE_CODE_OAUTH_TOKEN)
#   scripts/human/agents/sync-codex-runner.sh     (CODEX_AUTH_JSON_B64)
#   scripts/human/github/create-agent-app.sh      (AGENT_APP_ID, AGENT_APP_PRIVATE_KEY)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

gh_bin="${GH_BIN:-gh}"
repo_arg=""
check_only=0
non_interactive=0

arg_plan=""
arg_auto_heal=""
arg_auto_heal_merge=""
arg_telemetry_poll=""
arg_target_url=""
arg_error_reporter=""
arg_error_collector_endpoint=""
any_var_flag=0

todo=()

ok() { printf '  \033[32m✔\033[0m %s\n' "$1"; }
miss() { printf '  \033[33m✘\033[0m %s\n' "$1"; todo+=("$1"); }
note() { printf '  \033[36m•\033[0m %s\n' "$1"; }
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }

usage() {
  sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

validate_bool() {
  case "$2" in
    true|false) ;;
    *) echo "Invalid $1 value '$2' (expected true or false)" >&2; exit 2 ;;
  esac
}

validate_plan() {
  case "$1" in
    spark|blaze) ;;
    *) echo "Invalid --plan value '$1' (expected spark or blaze)" >&2; exit 2 ;;
  esac
}

validate_reporter() {
  case "$1" in
    none|spark-firestore|crashlytics-web|external) ;;
    *)
      echo "Invalid --error-reporter value '$1' (expected none, spark-firestore, crashlytics-web, or external)" >&2
      exit 2
      ;;
  esac
}

validate_url() {
  case "$2" in
    https://*|http://localhost*|http://127.0.0.1*) ;;
    *) echo "Invalid $1 URL '$2' (must start with https:// or http://localhost)" >&2; exit 2 ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      check_only=1
      shift
      ;;
    --no-interactive)
      non_interactive=1
      shift
      ;;
    --repo)
      [ "$#" -ge 2 ] || { echo "--repo requires <owner/name>" >&2; exit 2; }
      repo_arg="$2"
      shift 2
      ;;
    --plan)
      [ "$#" -ge 2 ] || { echo "--plan requires spark or blaze" >&2; exit 2; }
      validate_plan "$2"
      arg_plan="$2"
      any_var_flag=1
      shift 2
      ;;
    --auto-heal)
      [ "$#" -ge 2 ] || { echo "--auto-heal requires true or false" >&2; exit 2; }
      validate_bool "--auto-heal" "$2"
      arg_auto_heal="$2"
      any_var_flag=1
      shift 2
      ;;
    --auto-heal-merge)
      [ "$#" -ge 2 ] || { echo "--auto-heal-merge requires true or false" >&2; exit 2; }
      validate_bool "--auto-heal-merge" "$2"
      arg_auto_heal_merge="$2"
      any_var_flag=1
      shift 2
      ;;
    --telemetry-poll)
      [ "$#" -ge 2 ] || { echo "--telemetry-poll requires true or false" >&2; exit 2; }
      validate_bool "--telemetry-poll" "$2"
      arg_telemetry_poll="$2"
      any_var_flag=1
      shift 2
      ;;
    --target-url)
      [ "$#" -ge 2 ] || { echo "--target-url requires a URL" >&2; exit 2; }
      validate_url "--target-url" "$2"
      arg_target_url="$2"
      any_var_flag=1
      shift 2
      ;;
    --error-reporter)
      [ "$#" -ge 2 ] || { echo "--error-reporter requires a reporter mode" >&2; exit 2; }
      validate_reporter "$2"
      arg_error_reporter="$2"
      any_var_flag=1
      shift 2
      ;;
    --error-collector-endpoint)
      [ "$#" -ge 2 ] || { echo "--error-collector-endpoint requires a URL" >&2; exit 2; }
      validate_url "--error-collector-endpoint" "$2"
      arg_error_collector_endpoint="$2"
      any_var_flag=1
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

command -v "$gh_bin" >/dev/null 2>&1 || { echo "Missing required tool: $gh_bin" >&2; exit 1; }

gh_repo_flags=()
if [ -n "$repo_arg" ]; then
  gh_repo_flags=(-R "$repo_arg")
fi

gh_cmd() {
  "$gh_bin" "$@" "${gh_repo_flags[@]}"
}

is_interactive() {
  [ "$non_interactive" -eq 0 ] && [ -t 0 ] && [ -t 1 ]
}

prompt_yes_no() {
  local question="$1" default="$2" reply=""
  local hint="[y/N]"
  [ "$default" = "y" ] && hint="[Y/n]"
  printf '  %s %s ' "$question" "$hint"
  read -r reply || true
  reply="${reply:-$default}"
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_value() {
  local label="$1" default="$2" reply=""
  if [ -n "$default" ]; then
    printf '  %s [%s]: ' "$label" "$default" >&2
  else
    printf '  %s (leave blank to keep unset): ' "$label" >&2
  fi
  read -r reply || true
  if [ -n "$reply" ]; then
    printf '%s' "$reply"
  else
    printf '%s' "$default"
  fi
}

secrets_list=""
vars_json=""

refresh_github_state() {
  secrets_list="$(gh_cmd secret list --json name -q '.[].name' 2>/dev/null || true)"
  vars_json="$(gh_cmd variable list --json name,value 2>/dev/null || printf '[]')"
}

has_secret() {
  printf '%s\n' "$secrets_list" | grep -qx "$1"
}

get_var() {
  python3 -I -c '
import json, sys
name = sys.argv[1]
try:
    items = json.loads(sys.argv[2])
except Exception:
    items = []
for item in items:
    if item.get("name") == name:
        print(item.get("value", ""))
        break
' "$1" "$vars_json"
}

set_var() {
  local name="$1" value="$2"
  gh_cmd variable set "$name" --body "$value" >/dev/null
  ok "Set GitHub variable $name=$value"
}

step "GitHub access"
if ! "$gh_bin" auth status >/dev/null 2>&1; then
  miss "GitHub CLI is not authenticated; run: gh auth login"
  exit 1
fi
ok "GitHub CLI authenticated"
refresh_github_state

if [ "$check_only" -eq 0 ]; then
  # Step 1: Human-only secret wizards when running interactively.
  has_claude=0
  has_codex=0
  has_app_id=0
  has_app_key=0
  has_secret CLAUDE_CODE_OAUTH_TOKEN && has_claude=1
  has_secret CODEX_AUTH_JSON_B64 && has_codex=1
  has_secret AGENT_APP_ID && has_app_id=1
  has_secret AGENT_APP_PRIVATE_KEY && has_app_key=1

  if is_interactive; then
    if [ "$has_claude" -eq 0 ] && [ "$has_codex" -eq 0 ]; then
      step "Runner authentication secret (human-only wizard)"
      note "Autonomous healing requires CLAUDE_CODE_OAUTH_TOKEN or CODEX_AUTH_JSON_B64."
      if prompt_yes_no "Run scripts/human/agents/login-claude-runner.sh now?" "y"; then
        bash scripts/human/agents/login-claude-runner.sh
      elif prompt_yes_no "Run scripts/human/agents/sync-codex-runner.sh instead?" "n"; then
        bash scripts/human/agents/sync-codex-runner.sh
      fi
    fi

    if [ "$has_app_id" -eq 0 ] || [ "$has_app_key" -eq 0 ]; then
      step "GitHub App credentials (human-only wizard)"
      note "AGENT_APP_ID and AGENT_APP_PRIVATE_KEY let agent-created PRs trigger CI checks."
      if prompt_yes_no "Run scripts/human/github/create-agent-app.sh now?" "y"; then
        bash scripts/human/github/create-agent-app.sh
      fi
    fi
  fi

  # Step 2: Configure repository variables.
  step "Configure repository variables"
  if [ "$any_var_flag" -eq 1 ]; then
    [ -n "$arg_plan" ] && set_var FIREBASE_PLAN "$arg_plan"
    [ -n "$arg_auto_heal" ] && set_var AUTO_HEAL_ENABLED "$arg_auto_heal"
    [ -n "$arg_auto_heal_merge" ] && set_var AUTO_HEAL_MERGE "$arg_auto_heal_merge"
    [ -n "$arg_telemetry_poll" ] && set_var TELEMETRY_POLL_ENABLED "$arg_telemetry_poll"
    [ -n "$arg_target_url" ] && set_var MONITOR_TARGET_URL "$arg_target_url"
    if [ -n "$arg_error_reporter" ]; then
      if [ "$arg_error_reporter" = "external" ] && [ -z "$arg_error_collector_endpoint" ] && [ -z "$(get_var ERROR_COLLECTOR_ENDPOINT)" ]; then
        echo "ERROR_REPORTER=external requires --error-collector-endpoint (or an existing ERROR_COLLECTOR_ENDPOINT variable)" >&2
        exit 2
      fi
      set_var ERROR_REPORTER "$arg_error_reporter"
    fi
    [ -n "$arg_error_collector_endpoint" ] && set_var ERROR_COLLECTOR_ENDPOINT "$arg_error_collector_endpoint"
  elif is_interactive; then
    cur_plan="$(get_var FIREBASE_PLAN)"; cur_plan="${cur_plan:-spark}"
    cur_heal="$(get_var AUTO_HEAL_ENABLED)"; cur_heal="${cur_heal:-true}"
    cur_merge="$(get_var AUTO_HEAL_MERGE)"; cur_merge="${cur_merge:-false}"
    cur_poll="$(get_var TELEMETRY_POLL_ENABLED)"; cur_poll="${cur_poll:-false}"
    cur_url="$(get_var MONITOR_TARGET_URL)"
    cur_reporter="$(get_var ERROR_REPORTER)"; cur_reporter="${cur_reporter:-none}"
    cur_endpoint="$(get_var ERROR_COLLECTOR_ENDPOINT)"

    chosen_plan="$(prompt_value "FIREBASE_PLAN (spark|blaze)" "$cur_plan")"
    validate_plan "$chosen_plan"
    chosen_heal="$(prompt_value "AUTO_HEAL_ENABLED (true|false)" "$cur_heal")"
    validate_bool "AUTO_HEAL_ENABLED" "$chosen_heal"
    chosen_merge="$(prompt_value "AUTO_HEAL_MERGE (true|false)" "$cur_merge")"
    validate_bool "AUTO_HEAL_MERGE" "$chosen_merge"
    chosen_poll="$(prompt_value "TELEMETRY_POLL_ENABLED (true|false)" "$cur_poll")"
    validate_bool "TELEMETRY_POLL_ENABLED" "$chosen_poll"
    chosen_url="$(prompt_value "MONITOR_TARGET_URL (default: https://my-foodsavr-store.web.app)" "$cur_url")"
    if [ -n "$chosen_url" ]; then
      validate_url "MONITOR_TARGET_URL" "$chosen_url"
    fi
    chosen_reporter="$(prompt_value "ERROR_REPORTER (none|spark-firestore|crashlytics-web|external)" "$cur_reporter")"
    validate_reporter "$chosen_reporter"
    chosen_endpoint="$cur_endpoint"
    if [ "$chosen_reporter" = "external" ]; then
      chosen_endpoint="$(prompt_value "ERROR_COLLECTOR_ENDPOINT (https://...)" "$cur_endpoint")"
      validate_url "ERROR_COLLECTOR_ENDPOINT" "$chosen_endpoint"
    fi

    set_var FIREBASE_PLAN "$chosen_plan"
    set_var AUTO_HEAL_ENABLED "$chosen_heal"
    set_var AUTO_HEAL_MERGE "$chosen_merge"
    set_var TELEMETRY_POLL_ENABLED "$chosen_poll"
    [ -n "$chosen_url" ] && set_var MONITOR_TARGET_URL "$chosen_url"
    set_var ERROR_REPORTER "$chosen_reporter"
    [ -n "$chosen_endpoint" ] && set_var ERROR_COLLECTOR_ENDPOINT "$chosen_endpoint"
  else
    note "Non-interactive run with no variable flags; skipping variable updates."
  fi

  refresh_github_state
fi

# Audit section (runs in both --check and setup modes).
step "GitHub Secrets (human-only)"
if has_secret CLAUDE_CODE_OAUTH_TOKEN; then
  ok "CLAUDE_CODE_OAUTH_TOKEN is set"
fi
if has_secret CODEX_AUTH_JSON_B64; then
  ok "CODEX_AUTH_JSON_B64 is set"
fi
if ! has_secret CLAUDE_CODE_OAUTH_TOKEN && ! has_secret CODEX_AUTH_JSON_B64; then
  miss "Runner auth secret missing; run scripts/human/agents/login-claude-runner.sh or scripts/human/agents/sync-codex-runner.sh"
fi

if has_secret AGENT_APP_ID && has_secret AGENT_APP_PRIVATE_KEY; then
  ok "AGENT_APP_ID and AGENT_APP_PRIVATE_KEY are set"
else
  miss "Agent GitHub App secrets missing (AGENT_APP_ID / AGENT_APP_PRIVATE_KEY); run scripts/human/github/create-agent-app.sh"
fi

step "GitHub Repository Variables"
val_plan="$(get_var FIREBASE_PLAN)"
if [ -z "$val_plan" ]; then
  note "FIREBASE_PLAN unset (defaults to spark)"
elif [ "$val_plan" = "spark" ] || [ "$val_plan" = "blaze" ]; then
  ok "FIREBASE_PLAN=$val_plan"
else
  miss "FIREBASE_PLAN='$val_plan' is invalid (expected spark or blaze)"
fi

val_heal="$(get_var AUTO_HEAL_ENABLED)"
if [ "$val_heal" = "true" ]; then
  ok "AUTO_HEAL_ENABLED=true"
else
  miss "AUTO_HEAL_ENABLED is '${val_heal:-unset}'; enable via: make monitoring-setup ARGS='--auto-heal true'"
fi

val_merge="$(get_var AUTO_HEAL_MERGE)"
note "AUTO_HEAL_MERGE=${val_merge:-false (default)}"

val_poll="$(get_var TELEMETRY_POLL_ENABLED)"
note "TELEMETRY_POLL_ENABLED=${val_poll:-false (default)}"

val_url="$(get_var MONITOR_TARGET_URL)"
note "MONITOR_TARGET_URL=${val_url:-https://my-foodsavr-store.web.app (default)}"

val_reporter="$(get_var ERROR_REPORTER)"
val_endpoint="$(get_var ERROR_COLLECTOR_ENDPOINT)"
if [ -z "$val_reporter" ] || [ "$val_reporter" = "none" ]; then
  note "ERROR_REPORTER=${val_reporter:-none (default; synthetic Playwright probe active)}"
elif [ "$val_reporter" = "spark-firestore" ] || [ "$val_reporter" = "crashlytics-web" ]; then
  ok "ERROR_REPORTER=$val_reporter"
elif [ "$val_reporter" = "external" ]; then
  if [ -n "$val_endpoint" ]; then
    ok "ERROR_REPORTER=external (ERROR_COLLECTOR_ENDPOINT=$val_endpoint)"
  else
    miss "ERROR_REPORTER=external requires ERROR_COLLECTOR_ENDPOINT"
  fi
else
  miss "ERROR_REPORTER='$val_reporter' is invalid"
fi

if [ "$val_poll" = "true" ]; then
  if [ -n "$(get_var GCP_WORKLOAD_IDENTITY_PROVIDER)" ] && [ -n "$(get_var GCP_DEPLOY_SERVICE_ACCOUNT)" ]; then
    ok "GCP WIF configured for scheduled telemetry polling"
  else
    miss "TELEMETRY_POLL_ENABLED=true requires GCP_WORKLOAD_IDENTITY_PROVIDER and GCP_DEPLOY_SERVICE_ACCOUNT"
  fi
fi

step "Local monitoring workflows and scripts"
for required_file in \
  .github/workflows/web-monitor.yml \
  .github/workflows/fault-intake.yml \
  scripts/monitoring/probe_web.mjs \
  scripts/monitoring/fault_intake.py \
  scripts/monitoring/verify_and_close.py; do
  if [ -f "$required_file" ]; then
    ok "$required_file present"
  else
    miss "Missing $required_file"
  fi
done

if [ -d test/e2e/node_modules/@playwright/test ] || [ -d test/e2e/node_modules/playwright ]; then
  ok "Playwright installed in test/e2e (ready for make monitoring-probe)"
else
  note "Playwright not installed locally; run 'npm --prefix test/e2e ci' before 'make monitoring-probe'"
fi

echo ""
if [ "${#todo[@]}" -eq 0 ]; then
  echo "Monitoring and healing loop setup checks passed."
  exit 0
fi

echo "Monitoring setup incomplete (${#todo[@]} item(s) remaining):"
for item in "${todo[@]}"; do
  echo "  - $item"
done
exit 1
