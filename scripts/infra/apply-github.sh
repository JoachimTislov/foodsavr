#!/usr/bin/env bash
# Apply infra/terraform/github for a target GitHub repository (ADR 0008).
# Manages split rulesets, environments, non-secret Actions variables, singular
# labels, and default branch using worktree-safe XDG local state.
#
#   GITHUB_REPOSITORY=owner/repo [RELEASE_TOPOLOGY=single|two-stage|full-channels] \
#   [TFVARS_FILE=/path/to/github.tfvars] [PLAN_OUT=/path/to/github.tfplan] \
#   scripts/infra/apply-github.sh [plan|apply]
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
source_dir="$root/infra/terraform/github"
action="${1:-apply}"
case "$action" in
  plan|apply|show) ;;
  *) echo "Usage: $0 [plan|apply]" >&2; exit 2 ;;
esac

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required; install from https://developer.hashicorp.com/terraform/install" >&2
  exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required; install from https://cli.github.com" >&2
  exit 1
fi

repo_slug="${GITHUB_REPOSITORY:-}"
if [ -z "$repo_slug" ]; then
  repo_slug="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
fi
if [[ ! "$repo_slug" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "Set GITHUB_REPOSITORY=owner/repo (or run inside a configured gh repo)." >&2
  exit 1
fi

owner="${repo_slug%%/*}"
repo="${repo_slug#*/}"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  GITHUB_TOKEN="$(gh auth token)"
  export GITHUB_TOKEN
fi

# Auto-detect private repos on GitHub Free where repository rulesets return 403.
enable_rulesets="${ENABLE_RULESETS:-}"
if [ -z "$enable_rulesets" ]; then
  repo_private="$(gh api "repos/$repo_slug" --jq '.private' 2>/dev/null || echo false)"
  if [ "$repo_private" = true ]; then
    # Probe rulesets endpoint; 403/404 on private Free repo -> disable rulesets cleanly.
    if gh api "repos/$repo_slug/rulesets" >/dev/null 2>&1; then
      enable_rulesets=true
    else
      echo "Private repository without rulesets entitlement; setting enable_rulesets=false." >&2
      enable_rulesets=false
    fi
  else
    enable_rulesets=true
  fi
fi

state_path="$(python3 "$root/scripts/infra/bootstrap_support.py" state-path "$repo_slug" "github")"
state_dir="$(dirname "$state_path")"
mkdir -p "$state_dir"

umask 077
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/config"

python3 "$root/scripts/infra/bootstrap_support.py" config "$source_dir" "$work/config" local "$state_path"
if [[ "$action" != show && -z "${PLAN_FILE:-}" ]]; then
  existing="$(python3 "$root/scripts/infra/adopt.py" github "$work/config" "$repo_slug" "$enable_rulesets")"
  existing_var() { python3 -c 'import json, sys; print(json.loads(sys.argv[1])[sys.argv[2]])' "$existing" "$1"; }
  RELEASE_TOPOLOGY="${RELEASE_TOPOLOGY:-$(existing_var RELEASE_TOPOLOGY)}"
  AGENT_APP_ID="${AGENT_APP_ID:-$(existing_var AGENT_APP_ID)}"
  RELEASE_GATE_APP_ID="${RELEASE_GATE_APP_ID:-$(existing_var RELEASE_GATE_APP_ID)}"
fi
echo "Using local Terraform state: $state_path" >&2

tf_args=(
  "-var=github_owner=$owner"
  "-var=github_repository=$repo"
  "-var=enable_rulesets=$enable_rulesets"
  "-var=labels_file=$root/.agents/github/labels.json"
)
topology="${RELEASE_TOPOLOGY:-}"
if [ -z "$topology" ] && [ -z "${TFVARS_FILE:-}" ]; then
  topology=single
fi
if [ -n "$topology" ]; then
  tf_args+=("-var=release_topology=$topology")
  # A later tfvars assignment can change topology. Let Terraform derive the
  # channels from the effective topology unless the file supplies them.
  if [ -z "${TFVARS_FILE:-}" ]; then
    branches="$(python3 "$root/scripts/setup/setupctl.py" topology "$topology")"
    tf_args+=("-var=channel_branches=$branches")
  fi
fi
[ -n "${DEFAULT_BRANCH:-}" ] && tf_args+=("-var=default_branch=$DEFAULT_BRANCH")
[ -n "${AGENT_APP_ID:-}" ] && tf_args+=("-var=agent_app_id=$AGENT_APP_ID")
[ -n "${RELEASE_GATE_APP_ID:-}" ] && tf_args+=("-var=release_gate_app_id=$RELEASE_GATE_APP_ID")
# Instance state from the gitignored local state (DEPLOY_INSTANCE, FIREBASE_DEFINES_TEST).
instance_variables="$(python3 "$root/scripts/instance_local.py" ci-variables)"
[ "$instance_variables" != "{}" ] && tf_args+=("-var=instance_variables=$instance_variables")
[ -n "${TFVARS_FILE:-}" ] && tf_args+=("-var-file=$TFVARS_FILE")

terraform -chdir="$work/config" init -input=false

if [ "$action" = show ]; then
  terraform -chdir="$work/config" show -no-color "${PLAN_FILE:?Set PLAN_FILE}"
  exit 0
fi
if [ "$action" = plan ]; then
  plan_args=()
  [ -n "${PLAN_OUT:-}" ] && plan_args=("-out=$PLAN_OUT")
  [ "${TF_DETAILED_EXITCODE:-}" = 1 ] && plan_args+=("-detailed-exitcode")
  terraform -chdir="$work/config" plan -input=false "${tf_args[@]}" "${plan_args[@]}"
  exit 0
fi

if [ -n "${PLAN_FILE:-}" ]; then
  terraform -chdir="$work/config" apply "$PLAN_FILE"
else
  terraform -chdir="$work/config" apply "${tf_args[@]}"
fi
