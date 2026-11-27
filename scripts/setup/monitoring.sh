#!/usr/bin/env bash
# Single entry-point for FoodSavr web monitoring and the autonomous healing loop.
#
# Usage:
#   make monitoring
#   scripts/setup/monitoring.sh
#
# Behavior:
#   - Always prints a read-only audit of GitHub secrets, repository variables,
#     monitoring workflows, and local probe tooling.
#   - Only opens an interactive shell (with Spark-first defaults) when invoked
#     by a human in an interactive terminal. Non-interactive, CI, and coding
#     agent invocations stay strictly read-only and never prompt.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

gh_bin="${GH_BIN:-gh}"
# The test site recorded by make setup; empty on an unset-up clone (nothing is baked in).
default_target_url="$(python3 scripts/instance_local.py site-url)"

todo=()
secrets_list=""
vars_json="[]"

ok() { printf '  \033[32m✔\033[0m %s\n' "$1"; }
miss() { printf '  \033[33m✘\033[0m %s\n' "$1"; todo+=("$1"); }
note() { printf '  \033[36m•\033[0m %s\n' "$1"; }
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }

is_human_interactive() {
  [ -t 0 ] && [ -t 1 ] || return 1
  [ "${TERM:-dumb}" != "dumb" ] || return 1
  [ -z "${CI:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ] || return 1
  [ -z "${ANTIGRAVITY_AGENT:-}" ] || return 1
  [ -z "${CLAUDECODE:-}" ] && [ -z "${CLAUDE_AGENT_SDK_VERSION:-}" ] || return 1
  [ -z "${CODEX_CI:-}" ] && [ -z "${CODEX_THREAD_ID:-}" ] && [ -z "${CODEX_SANDBOX:-}" ] || return 1
  [ -z "${GEMINI_CLI:-}" ] && [ -z "${OPENCODE:-}" ] && [ -z "${COPILOT_CLI:-}" ] || return 1
  [ -z "${AGENT_RUNNER:-}" ] || return 1
  return 0
}

valid_bool() {
  case "$1" in
    true|false) return 0 ;;
    *) return 1 ;;
  esac
}

valid_plan() {
  case "$1" in
    spark|blaze) return 0 ;;
    *) return 1 ;;
  esac
}

valid_reporter() {
  case "$1" in
    none|spark-firestore|crashlytics-web|external) return 0 ;;
    *) return 1 ;;
  esac
}

valid_url() {
  case "$1" in
    https://*|http://localhost*|http://127.0.0.1*) return 0 ;;
    *) return 1 ;;
  esac
}

refresh_github_state() {
  secrets_list="$("$gh_bin" secret list --json name -q '.[].name' 2>/dev/null || true)"
  vars_json="$("$gh_bin" variable list --json name,value 2>/dev/null || printf '[]')"
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
  "$gh_bin" variable set "$name" --body "$value" >/dev/null
  ok "Set GitHub variable $name=$value"
}

run_audit() {
  todo=()
  refresh_github_state

  step "GitHub Secrets (human-only)"
  if has_secret CLAUDE_CODE_OAUTH_TOKEN; then
    ok "CLAUDE_CODE_OAUTH_TOKEN is set"
  fi
  if has_secret CODEX_AUTH_JSON_B64; then
    ok "CODEX_AUTH_JSON_B64 is set"
  fi
  if has_secret ANTIGRAVITY_OAUTH_TOKEN_B64; then
    ok "ANTIGRAVITY_OAUTH_TOKEN_B64 is set"
  fi
  if has_secret GEMINI_API_KEY; then
    ok "GEMINI_API_KEY is set"
  fi
  if ! has_secret CLAUDE_CODE_OAUTH_TOKEN && ! has_secret CODEX_AUTH_JSON_B64 && ! has_secret ANTIGRAVITY_OAUTH_TOKEN_B64 && ! has_secret GEMINI_API_KEY; then
    miss "Runner auth secret missing; run scripts/human/agents/login-claude-runner.sh, scripts/human/agents/sync-codex-runner.sh, or scripts/human/agents/sync-antigravity-runner.sh"
  fi

  if has_secret AGENT_APP_ID && has_secret AGENT_APP_PRIVATE_KEY; then
    ok "AGENT_APP_ID and AGENT_APP_PRIVATE_KEY are set"
  else
    miss "Agent GitHub App secrets missing (AGENT_APP_ID / AGENT_APP_PRIVATE_KEY); run scripts/human/github/create-agent-app.sh"
  fi

  step "GitHub Repository Variables"
  local val_plan val_heal val_merge val_poll val_url val_reporter val_endpoint
  val_plan="$(get_var FIREBASE_PLAN)"
  if [ -z "$val_plan" ]; then
    note "FIREBASE_PLAN unset (defaults to spark)"
  elif valid_plan "$val_plan"; then
    ok "FIREBASE_PLAN=$val_plan"
  else
    miss "FIREBASE_PLAN='$val_plan' is invalid (expected spark or blaze)"
  fi

  val_heal="$(get_var AUTO_HEAL_ENABLED)"
  if [ "$val_heal" = "true" ]; then
    ok "AUTO_HEAL_ENABLED=true"
  else
    miss "AUTO_HEAL_ENABLED is '${val_heal:-unset}' (run 'make monitoring' in a terminal to enable)"
  fi

  val_merge="$(get_var AUTO_HEAL_MERGE)"
  note "AUTO_HEAL_MERGE=${val_merge:-false (default)}"

  val_poll="$(get_var TELEMETRY_POLL_ENABLED)"
  note "TELEMETRY_POLL_ENABLED=${val_poll:-false (default)}"

  val_url="$(get_var MONITOR_TARGET_URL)"
  note "MONITOR_TARGET_URL=${val_url:-$default_target_url (default)}"
  recorded_sites="$(python3 scripts/instance_local.py site-urls)"
  if [ -n "$val_url" ] && [ -n "$recorded_sites" ] && ! grep -qxF "${val_url%/}" <<<"$recorded_sites"; then
    miss "MONITOR_TARGET_URL ($val_url) is not a Hosting site recorded by make setup"
  fi

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
  local required_file
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
    ok "Playwright installed in test/e2e"
  else
    note "Playwright not installed locally; run 'npm --prefix test/e2e ci' to probe locally"
  fi
}

print_audit_summary() {
  echo ""
  if [ "${#todo[@]}" -eq 0 ]; then
    echo "Monitoring and healing loop setup checks passed."
    return 0
  fi

  echo "Monitoring setup incomplete (${#todo[@]} item(s) remaining):"
  local item
  for item in "${todo[@]}"; do
    echo "  - $item"
  done
  return 1
}

prompt_yes_no() {
  local question="$1" default="$2" reply=""
  local hint="[y/N]"
  [ "$default" = "y" ] && hint="[Y/n]"
  printf '  %s %s ' "$question" "$hint"
  if ! read -r reply; then
    return 2
  fi
  reply="${reply:-$default}"
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_validated() {
  local label="$1" default="$2" validator="$3" allow_empty="${4:-0}" reply=""
  while true; do
    if [ -n "$default" ]; then
      printf '  %s [%s]: ' "$label" "$default" >&2
    else
      printf '  %s: ' "$label" >&2
    fi
    if ! read -r reply; then
      return 1
    fi
    reply="${reply:-$default}"
    if [ -z "$reply" ] && [ "$allow_empty" -eq 1 ]; then
      printf '%s' ""
      return 0
    fi
    if "$validator" "$reply"; then
      printf '%s' "$reply"
      return 0
    fi
    printf '  Invalid value "%s". Please try again.\n' "$reply" >&2
  done
}

configure_interactive() {
  local has_claude=0 has_codex=0 has_app_id=0 has_app_key=0 rc=0
  has_secret CLAUDE_CODE_OAUTH_TOKEN && has_claude=1
  has_secret CODEX_AUTH_JSON_B64 && has_codex=1
  has_secret AGENT_APP_ID && has_app_id=1
  has_secret AGENT_APP_PRIVATE_KEY && has_app_key=1

  if [ "$has_claude" -eq 0 ] && [ "$has_codex" -eq 0 ]; then
    step "Runner authentication secret (human-only wizard)"
    note "Autonomous healing requires CLAUDE_CODE_OAUTH_TOKEN or CODEX_AUTH_JSON_B64."
    rc=0
    prompt_yes_no "Run scripts/human/agents/login-claude-runner.sh now?" "n" || rc=$?
    if [ "$rc" -eq 0 ]; then
      bash scripts/human/agents/login-claude-runner.sh
    elif [ "$rc" -eq 1 ]; then
      rc=0
      prompt_yes_no "Run scripts/human/agents/sync-codex-runner.sh instead?" "n" || rc=$?
      [ "$rc" -eq 0 ] && bash scripts/human/agents/sync-codex-runner.sh
    fi
  fi

  if [ "$has_app_id" -eq 0 ] || [ "$has_app_key" -eq 0 ]; then
    step "GitHub App credentials (human-only wizard)"
    note "AGENT_APP_ID and AGENT_APP_PRIVATE_KEY let agent-created PRs trigger CI checks."
    rc=0
    prompt_yes_no "Run scripts/human/github/create-agent-app.sh now?" "n" || rc=$?
    [ "$rc" -eq 0 ] && bash scripts/human/github/create-agent-app.sh
  fi

  step "Configure GitHub Repository Variables (press Enter to accept defaults)"
  local cur_plan cur_heal cur_merge cur_poll cur_url cur_reporter cur_endpoint
  cur_plan="$(get_var FIREBASE_PLAN)"; cur_plan="${cur_plan:-spark}"
  cur_heal="$(get_var AUTO_HEAL_ENABLED)"; cur_heal="${cur_heal:-true}"
  cur_merge="$(get_var AUTO_HEAL_MERGE)"; cur_merge="${cur_merge:-false}"
  cur_poll="$(get_var TELEMETRY_POLL_ENABLED)"; cur_poll="${cur_poll:-false}"
  cur_url="$(get_var MONITOR_TARGET_URL)"; cur_url="${cur_url:-$default_target_url}"
  cur_reporter="$(get_var ERROR_REPORTER)"; cur_reporter="${cur_reporter:-none}"
  cur_endpoint="$(get_var ERROR_COLLECTOR_ENDPOINT)"

  local chosen_plan chosen_heal chosen_merge chosen_poll chosen_url chosen_reporter chosen_endpoint
  chosen_plan="$(prompt_validated "FIREBASE_PLAN (spark|blaze)" "$cur_plan" valid_plan)" || return 0
  chosen_heal="$(prompt_validated "AUTO_HEAL_ENABLED (true|false)" "$cur_heal" valid_bool)" || return 0
  chosen_merge="$(prompt_validated "AUTO_HEAL_MERGE (true|false)" "$cur_merge" valid_bool)" || return 0
  chosen_poll="$(prompt_validated "TELEMETRY_POLL_ENABLED (true|false)" "$cur_poll" valid_bool)" || return 0
  chosen_url="$(prompt_validated "MONITOR_TARGET_URL" "$cur_url" valid_url)" || return 0
  chosen_reporter="$(prompt_validated "ERROR_REPORTER (none|spark-firestore|crashlytics-web|external)" "$cur_reporter" valid_reporter)" || return 0
  chosen_endpoint="$cur_endpoint"
  if [ "$chosen_reporter" = "external" ]; then
    chosen_endpoint="$(prompt_validated "ERROR_COLLECTOR_ENDPOINT (https://...)" "$cur_endpoint" valid_url)" || return 0
  fi

  set_var FIREBASE_PLAN "$chosen_plan"
  set_var AUTO_HEAL_ENABLED "$chosen_heal"
  set_var AUTO_HEAL_MERGE "$chosen_merge"
  set_var TELEMETRY_POLL_ENABLED "$chosen_poll"
  set_var MONITOR_TARGET_URL "$chosen_url"
  set_var ERROR_REPORTER "$chosen_reporter"
  [ -n "$chosen_endpoint" ] && set_var ERROR_COLLECTOR_ENDPOINT "$chosen_endpoint"

  run_audit
  print_audit_summary || true
}

run_probe_interactive() {
  local cur_url target_url
  cur_url="$(get_var MONITOR_TARGET_URL)"; cur_url="${cur_url:-$default_target_url}"
  target_url="$(prompt_validated "Target URL to probe" "$cur_url" valid_url)" || return 0
  step "Running Playwright web probe against $target_url"
  node scripts/monitoring/probe_web.mjs --url "$target_url" || true
}

run_tests_interactive() {
  step "Running monitoring unit tests"
  python3 -m unittest discover -s scripts/monitoring -p "test_*.py" || true
}

interactive_shell() {
  local choice=""
  while true; do
    step "Monitoring shell"
    printf '  [1] Configure monitoring & healing (default)\n'
    printf '  [2] Run live web probe\n'
    printf '  [3] Run monitoring unit tests\n'
    printf '  [4] Refresh status\n'
    printf '  [q] Quit\n'
    printf '  Select [1]: '
    if ! read -r choice; then
      echo ""
      break
    fi
    choice="${choice:-1}"
    case "$choice" in
      1) configure_interactive ;;
      2) run_probe_interactive ;;
      3) run_tests_interactive ;;
      4) run_audit; print_audit_summary || true ;;
      q|Q|quit|exit) break ;;
      *) echo "  Unknown option: $choice" ;;
    esac
  done
}

command -v "$gh_bin" >/dev/null 2>&1 || { echo "Missing required tool: $gh_bin" >&2; exit 1; }

step "GitHub access"
if ! "$gh_bin" auth status >/dev/null 2>&1; then
  miss "GitHub CLI is not authenticated; run: gh auth login"
  exit 1
fi
ok "GitHub CLI authenticated"

run_audit

if is_human_interactive; then
  print_audit_summary || true
  interactive_shell
  exit 0
fi

print_audit_summary
