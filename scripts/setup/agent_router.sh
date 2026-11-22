#!/usr/bin/env bash
# Idempotent setup, diagnostics, and live probe for the agent decision router.
#
# Usage:
#   scripts/setup/agent_router.sh [--check] [--local-only] [--enable-remote] [--probe]
#                                 [--override-file <path> | --in-place]
#                                 [--base-url <https://...>] [--model <id>]
#                                 [--timeout-ms <int>] [--engine <name>]
#                                 [--allow-host] [--no-control-plane-on-none] [--github]
#
# Modes:
#   --check          Non-mutating audit of ROUTER_* env/.env, router manifest,
#                    policy allow_hosts alignment, agentctl doctor, and local
#                    router decide smoke check.
#   --local-only     Configure/verify deterministic local LocalWorkClassifier +
#                    work_routes matrix mode (decision_provider.enabled=false)
#                    and run `agentctl heal` + `agentctl router matrix`.
#   --enable-remote  Validate ROUTER_BASE_URL (https://), ROUTER_API_KEY, and
#                    ROUTER_MODEL (from flags, env, .env, or TTY prompt), persist
#                    exclusively via `scripts/secrets/rotate.py`, and configure
#                    the override manifest (default .agents/state/router.override.json)
#                    or `.agents/runners/router.json` (--in-place).
#   --probe          Perform a live HTTPS /chat/completions probe against
#                    ROUTER_BASE_URL/ROUTER_MODEL with strict route_decision
#                    JSON Schema validation and report latency + selection.
#
# Environment overrides (optional):
#   ROUTER_BASE_URL, ROUTER_API_KEY, ROUTER_MODEL
#   SET_GITHUB_SECRETS=1   Also sync ROUTER_* to GitHub Actions via rotate.py
#   AGENT_ROUTER_FILE, AGENT_POLICY_FILE, AGENT_RUNNERS_FILE, AGENT_ENV_FILE
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

env_file="${AGENT_ENV_FILE:-$repo_root/.env}"
default_router_file="$repo_root/.agents/runners/router.json"
active_router_file="${AGENT_ROUTER_FILE:-$default_router_file}"
default_override_file="$repo_root/.agents/state/router.override.json"

mode=""
do_probe=0
override_file=""
override_set=0
in_place=0
push_github="${SET_GITHUB_SECRETS:-0}"
add_allow_host=0
allow_cp_on_none=1
arg_base_url=""
arg_model=""
arg_timeout_ms=""
arg_engine=""
todo=()

ok() { printf '  \033[32m✔\033[0m %s\n' "$1"; }
miss() { printf '  \033[33m✘\033[0m %s\n' "$1"; todo+=("$1"); }
note() { printf '  \033[36m•\033[0m %s\n' "$1"; }
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }

usage() {
  sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      [ -n "$mode" ] && [ "$mode" != "check" ] && { echo "Conflicting mode flags: $mode and --check" >&2; exit 2; }
      mode="check"
      shift
      ;;
    --local-only)
      [ -n "$mode" ] && [ "$mode" != "local-only" ] && { echo "Conflicting mode flags: $mode and --local-only" >&2; exit 2; }
      mode="local-only"
      shift
      ;;
    --enable-remote)
      [ -n "$mode" ] && [ "$mode" != "enable-remote" ] && { echo "Conflicting mode flags: $mode and --enable-remote" >&2; exit 2; }
      mode="enable-remote"
      shift
      ;;
    --probe)
      do_probe=1
      shift
      ;;
    --override-file)
      [ "$#" -ge 2 ] || { echo "--override-file requires a path argument" >&2; exit 2; }
      override_file="$2"
      override_set=1
      shift 2
      ;;
    --in-place)
      in_place=1
      shift
      ;;
    --github)
      push_github=1
      shift
      ;;
    --allow-host)
      add_allow_host=1
      shift
      ;;
    --no-control-plane-on-none)
      allow_cp_on_none=0
      shift
      ;;
    --base-url)
      [ "$#" -ge 2 ] || { echo "--base-url requires a URL argument" >&2; exit 2; }
      arg_base_url="$2"
      shift 2
      ;;
    --model)
      [ "$#" -ge 2 ] || { echo "--model requires a model ID" >&2; exit 2; }
      arg_model="$2"
      shift 2
      ;;
    --timeout-ms)
      [ "$#" -ge 2 ] || { echo "--timeout-ms requires an integer >= 50" >&2; exit 2; }
      arg_timeout_ms="$2"
      shift 2
      ;;
    --engine)
      [ "$#" -ge 2 ] || { echo "--engine requires an engine identifier" >&2; exit 2; }
      arg_engine="$2"
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

if [ "$in_place" = 1 ] && [ "$override_set" = 1 ]; then
  echo "Cannot combine --in-place and --override-file" >&2
  exit 2
fi

for tool in python3; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done

# Preserve non-empty caller-provided ROUTER_* env vars over .env defaults.
caller_url="${ROUTER_BASE_URL:-}"
caller_key="${ROUTER_API_KEY:-}"
caller_model="${ROUTER_MODEL:-}"

if [ -f "$env_file" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$env_file"
  set +a
fi

[ -n "$caller_url" ] && export ROUTER_BASE_URL="$caller_url"
[ -n "$caller_key" ] && export ROUTER_API_KEY="$caller_key"
[ -n "$caller_model" ] && export ROUTER_MODEL="$caller_model"
[ -n "$arg_base_url" ] && export ROUTER_BASE_URL="$arg_base_url"
[ -n "$arg_model" ] && export ROUTER_MODEL="$arg_model"

if [ -z "$mode" ]; then
  if [ "$do_probe" = 1 ]; then
    mode="probe-only"
  elif [ -n "$arg_base_url" ] || [ -n "$arg_model" ]; then
    mode="enable-remote"
  elif [ -n "${ROUTER_BASE_URL:-}" ] && [ -n "${ROUTER_API_KEY:-}" ] && [ -n "${ROUTER_MODEL:-}" ]; then
    mode="enable-remote"
  elif [ -t 0 ]; then
    step "Agent Router Setup"
    note "No mode flag specified. Choose: [l]ocal deterministic mode or [r]emote decision router?"
    printf '  Select mode [l/r] (default: l): '
    read -r choice
    case "${choice,,}" in
      r|remote) mode="enable-remote" ;;
      *) mode="local-only" ;;
    esac
  else
    mode="local-only"
  fi
fi

validate_https_url() {
  python3 -I - "$1" <<'PY'
import sys, urllib.parse
url = sys.argv[1].strip()
parsed = urllib.parse.urlparse(url)
if parsed.scheme != "https" or not parsed.hostname or any(ch.isspace() for ch in url):
    sys.exit(1)
print(parsed.hostname)
PY
}

agentctl_cmd() {
  python3 "$repo_root/scripts/agents/agentctl.py" "$@"
}

run_check() {
  step "Router configuration"
  local status_json
  if ! status_json="$(AGENT_ROUTER_FILE="$active_router_file" agentctl_cmd router status 2>&1)"; then
    miss "agentctl router status failed: $status_json"
    return
  fi

  local fields=()
  mapfile -t fields < <(printf '%s' "$status_json" | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
dp = d["decision_provider"]
env = d["environment"]
hl = d["host_allowlist"]
for val in [
    d["router_file"],
    str(d["router_override_active"]).lower(),
    str(dp["enabled"]).lower(),
    str(dp.get("engine") or ""),
    str(dp["allow_control_plane_on_none"]).lower(),
    str(dp["timeout_ms"]),
    d["policy_id"],
    d["policy_network"],
    str(env[dp["base_url_env"]]["set"]).lower(),
    str(env[dp["base_url_env"]]["https"]).lower(),
    str(env[dp["base_url_env"]]["host"] or ""),
    str(env[dp["api_key_env"]]["set"]).lower(),
    str(env[dp["model_env"]]["set"]).lower(),
    str(env[dp["model_env"]]["value"] or ""),
    str(hl["in_allow_hosts"]).lower(),
    ",".join(d["available_providers"]),
    ",".join(d["policy_safe_providers"]),
    d["effective_mode"],
]:
    print(val.replace("\n", " "))
')

  local r_file="${fields[0]:-}" r_override="${fields[1]:-}" r_enabled="${fields[2]:-}"
  local r_engine="${fields[3]:-}" r_cp_none="${fields[4]:-}" r_timeout="${fields[5]:-}"
  local p_id="${fields[6]:-}" p_net="${fields[7]:-}"
  local url_set="${fields[8]:-}" url_https="${fields[9]:-}" url_host="${fields[10]:-}"
  local key_set="${fields[11]:-}" model_set="${fields[12]:-}" model_val="${fields[13]:-}"
  local in_allow="${fields[14]:-}" avail_list="${fields[15]:-}" safe_list="${fields[16]:-}"
  local eff_mode="${fields[17]:-}"

  ok "Router manifest: $r_file (override=$r_override, engine=${r_engine:-none}, timeout=${r_timeout}ms)"
  if [ "$r_enabled" = true ]; then
    ok "decision_provider.enabled=true (effective mode: $eff_mode)"
  else
    note "decision_provider.enabled=false (deterministic local mode)"
  fi

  step "Credentials & URL validation"
  if [ "$url_set" = true ]; then
    if [ "$url_https" = true ]; then
      ok "ROUTER_BASE_URL uses https:// (host: $url_host)"
    else
      miss "ROUTER_BASE_URL must use https:// with a valid hostname"
    fi
  elif [ "$r_enabled" = true ]; then
    miss "ROUTER_BASE_URL is not set in environment or $env_file"
  else
    note "ROUTER_BASE_URL not set (optional while decision_provider.enabled=false)"
  fi

  if [ "$key_set" = true ]; then
    ok "ROUTER_API_KEY is set"
  elif [ "$r_enabled" = true ]; then
    miss "ROUTER_API_KEY is not set in environment or $env_file"
  else
    note "ROUTER_API_KEY not set (optional while decision_provider.enabled=false)"
  fi

  if [ "$model_set" = true ]; then
    ok "ROUTER_MODEL is set ($model_val)"
  elif [ "$r_enabled" = true ]; then
    miss "ROUTER_MODEL is not set in environment or $env_file"
  else
    note "ROUTER_MODEL not set (optional while decision_provider.enabled=false)"
  fi

  step "Policy & allow_hosts alignment"
  if [ "$p_net" = "none" ]; then
    if [ "$r_enabled" = true ] && [ "$r_cp_none" != true ]; then
      miss "Policy '$p_id' has network=none and allow_control_plane_on_none=false"
    elif [ "$r_enabled" = true ]; then
      ok "Policy '$p_id' network=none allowed via allow_control_plane_on_none=true"
    else
      ok "Policy '$p_id' network=none aligns with local deterministic mode"
    fi
  elif [ "$p_net" = "allowlisted" ]; then
    if [ "$r_enabled" = true ] && [ "$in_allow" != true ]; then
      miss "Router host '${url_host:-<unset>}' is not in policy '$p_id' allow_hosts"
    elif [ "$r_enabled" = true ]; then
      ok "Router host '$url_host' is allowlisted in policy '$p_id'"
    else
      ok "Policy '$p_id' network=allowlisted ready"
    fi
  else
    ok "Policy '$p_id' network=$p_net allows outbound router requests"
  fi

  step "Provider runner doctor"
  local doctor_json
  if ! doctor_json="$(agentctl_cmd doctor 2>&1)"; then
    miss "agentctl doctor failed"
  else
    if [ -n "$safe_list" ]; then
      ok "Policy-safe providers: $safe_list (installed: ${avail_list:-none})"
    else
      note "Installed providers: ${avail_list:-none}; 0 policy-safe providers for baseline policy (planning still succeeds and execution fails closed)"
    fi
  fi

  step "Local routing smoke check"
  local decide_json
  if ! decide_json="$(AGENT_ROUTER_FILE="$active_router_file" agentctl_cmd router decide --role implementer --prompt "Smoke check local routing" 2>&1)"; then
    miss "agentctl router decide smoke check failed: $decide_json"
  else
    local decide_summary
    decide_summary="$(printf '%s' "$decide_json" | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
wp = d["work_profile"]
dec = d.get("decision")
if dec:
    print("selected={}/{} work_type={} tier={} reason={}".format(
        dec["provider"], dec["model"], dec["work_type"], dec["tier"], d["reason"]))
else:
    print("classified work_type={} tier={} (no policy-safe binary on PATH; reason={})".format(
        wp["work_type"], wp["tier"], d["reason"]))
')"
    ok "router decide: $decide_summary"
  fi
}

run_local_only() {
  local target_router=""
  if [ "$in_place" = 1 ]; then
    target_router="$active_router_file"
  elif [ "$override_set" = 1 ]; then
    target_router="$override_file"
  elif [ -f "$default_override_file" ] || [ "$active_router_file" != "$default_router_file" ]; then
    target_router="${override_file:-$active_router_file}"
    [ "$active_router_file" = "$default_router_file" ] && target_router="$default_override_file"
  fi

  step "Configure deterministic local mode"
  if [ -n "$target_router" ]; then
    local cfg_args=(router configure --disable --no-allow-control-plane-on-none --output "$target_router")
    [ -n "$arg_timeout_ms" ] && cfg_args+=(--timeout-ms "$arg_timeout_ms")
    [ -n "$arg_engine" ] && cfg_args+=(--engine "$arg_engine")
    if agentctl_cmd "${cfg_args[@]}" >/dev/null; then
      ok "Configured local deterministic mode at $target_router"
      active_router_file="$target_router"
    else
      miss "Failed to configure local router manifest at $target_router"
      return
    fi
  else
    local enabled_now
    enabled_now="$(AGENT_ROUTER_FILE="$active_router_file" agentctl_cmd router status | python3 -I -c 'import json,sys; print(str(json.load(sys.stdin)["decision_provider"]["enabled"]).lower())')"
    if [ "$enabled_now" = true ]; then
      if agentctl_cmd router configure --disable --no-allow-control-plane-on-none --output "$default_override_file" >/dev/null; then
        ok "Wrote local-only override at $default_override_file (tracked router.json left untouched)"
        active_router_file="$default_override_file"
      else
        miss "Failed to write local-only override at $default_override_file"
        return
      fi
    else
      ok "Active router already in deterministic local mode ($active_router_file)"
    fi
  fi

  step "Heal state & verify routing matrix"
  if agentctl_cmd heal >/dev/null; then
    ok "agentctl heal healthy"
  else
    miss "agentctl heal failed"
  fi

  local matrix_summary
  if matrix_summary="$(AGENT_ROUTER_FILE="$active_router_file" agentctl_cmd router matrix | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
print("router={} work_types={} tiers={}".format(d["router"], len(d["matrix"]), len(d["tiers"])))
')"; then
    ok "agentctl router matrix: $matrix_summary"
  else
    miss "agentctl router matrix failed"
  fi

  if [ "$active_router_file" != "$default_router_file" ]; then
    note "Activate override in your shell with: export AGENT_ROUTER_FILE=\"$active_router_file\""
  fi
}

run_enable_remote() {
  step "Remote decision router credentials"
  local url="${ROUTER_BASE_URL:-}"
  local key="${ROUTER_API_KEY:-}"
  local model="${ROUTER_MODEL:-}"

  if [ -z "$url" ]; then
    if [ -t 0 ]; then
      printf '  ROUTER_BASE_URL (https://...): '
      read -r url
    else
      miss "ROUTER_BASE_URL is required (pass --base-url or set ROUTER_BASE_URL)"
    fi
  fi
  if [ -z "$key" ]; then
    if [ -t 0 ]; then
      printf '  ROUTER_API_KEY (hidden): '
      read -rs key
      printf '\n'
    else
      miss "ROUTER_API_KEY is required (set ROUTER_API_KEY in environment or .env)"
    fi
  fi
  if [ -z "$model" ]; then
    if [ -t 0 ]; then
      printf '  ROUTER_MODEL (e.g. gpt-6.2-sol or decision model ID): '
      read -r model
    else
      miss "ROUTER_MODEL is required (pass --model or set ROUTER_MODEL)"
    fi
  fi

  if [ "${#todo[@]}" -gt 0 ]; then
    return
  fi

  local router_host=""
  if ! router_host="$(validate_https_url "$url")"; then
    miss "ROUTER_BASE_URL must start with https:// and contain a valid hostname"
    return
  fi
  ok "Validated HTTPS endpoint host: $router_host"
  export ROUTER_BASE_URL="$url"
  export ROUTER_API_KEY="$key"
  export ROUTER_MODEL="$model"

  step "Persist ROUTER_* credentials via scripts/secrets/rotate.py"
  if [ ! -f "$repo_root/scripts/secrets/rotate.py" ]; then
    miss "scripts/secrets/rotate.py is missing"
    return
  fi

  local sink_args=(--only-sink env)
  if [ "$push_github" = 1 ]; then
    sink_args+=(--only-sink github)
  fi

  if (
    export NEW_ROUTER_BASE_URL="$url"
    export NEW_ROUTER_API_KEY="$key"
    export NEW_ROUTER_MODEL="$model"
    exec python3 "$repo_root/scripts/secrets/rotate.py" --env-file "$env_file" "${sink_args[@]}" ROUTER_BASE_URL ROUTER_API_KEY ROUTER_MODEL
  ) </dev/null; then
    if [ "$push_github" = 1 ]; then
      ok "Persisted ROUTER_BASE_URL, ROUTER_API_KEY, ROUTER_MODEL to $env_file and GitHub secrets via rotate.py"
    else
      ok "Persisted ROUTER_BASE_URL, ROUTER_API_KEY, ROUTER_MODEL to $env_file via rotate.py"
    fi
  else
    miss "scripts/secrets/rotate.py failed for ROUTER_*"
    return
  fi

  step "Configure router manifest"
  local target_router="$default_override_file"
  if [ "$in_place" = 1 ]; then
    target_router="$active_router_file"
  elif [ "$override_set" = 1 ]; then
    target_router="$override_file"
  fi

  local cfg_args=(router configure --enable --output "$target_router")
  if [ "$allow_cp_on_none" = 1 ]; then
    cfg_args+=(--allow-control-plane-on-none)
  else
    cfg_args+=(--no-allow-control-plane-on-none)
  fi
  [ -n "$arg_timeout_ms" ] && cfg_args+=(--timeout-ms "$arg_timeout_ms")
  [ -n "$arg_engine" ] && cfg_args+=(--engine "$arg_engine")
  if [ "$add_allow_host" = 1 ]; then
    cfg_args+=(--allow-host "$router_host" --update-policy)
  fi

  if agentctl_cmd "${cfg_args[@]}" >/dev/null; then
    ok "Wrote validated router config to $target_router"
    active_router_file="$target_router"
  else
    miss "agentctl router configure failed for $target_router"
    return
  fi

  if [ "$add_allow_host" = 1 ]; then
    ok "Added $router_host to policy allow_hosts"
  fi
  if [ "$target_router" != "$default_router_file" ]; then
    note "Activate override in your shell with: export AGENT_ROUTER_FILE=\"$target_router\""
  fi
}

run_probe() {
  step "Live remote decision probe"
  local url="${ROUTER_BASE_URL:-}"
  local key="${ROUTER_API_KEY:-}"
  local model="${ROUTER_MODEL:-auto}"
  if [ -z "$url" ]; then
    miss "Cannot probe: ROUTER_BASE_URL is not set"
    return
  fi
  if ! validate_https_url "$url" >/dev/null; then
    miss "Cannot probe: ROUTER_BASE_URL must use https:// with a valid hostname"
    return
  fi
  if [ -z "$key" ]; then
    miss "Cannot probe: ROUTER_API_KEY is not set"
    return
  fi

  local probe_out
  if ! probe_out="$(AGENT_ROUTER_FILE="$active_router_file" python3 - "$repo_root" "$url" "$model" <<'PY'
import importlib.util
import json
import shutil
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

repo_root = Path(sys.argv[1])
base_url = sys.argv[2].rstrip("/")
model = sys.argv[3]

spec = importlib.util.spec_from_file_location("agentctl", repo_root / "scripts/agents/agentctl.py")
agentctl = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(agentctl)

router = agentctl.load_json(agentctl.ROUTER)
policy = agentctl.load_json(agentctl.POLICY)
specs = agentctl.provider_specs()
permissions = {field: policy.get(field, "none") for field in ("filesystem", "network", "git", "github")}
safe = [
    provider for provider, pspec in specs.items()
    if shutil.which(pspec.get("command", "")) is not None
    and agentctl.capability_report(provider, agentctl.effective_spec(pspec, permissions), permissions)["policy_safe"]
]
allowed_providers = safe or list(specs.keys())
workflow = {
    "schema_version": 1,
    "id": "router-live-probe",
    "objective": "Verify remote decision routing contract",
    "permissions": permissions,
}
step = {
    "id": "probe",
    "role": "implementer",
    "prompt": "Implement a small validated configuration change",
    "acceptance": ["passes check"],
}
profile = agentctl.infer_work_profile(workflow, step, router)
candidates = agentctl.build_model_candidates(allowed_providers, specs, safe or allowed_providers)
available_models = list(dict.fromkeys(c.model for c in candidates))
default_models = {
    p: (agentctl._best_model_for_provider(specs.get(p, {}), profile, None) or "default")
    for p in allowed_providers
}
route_request = agentctl.RouteRequest(
    workflow_id=workflow["id"],
    step_id=step["id"],
    work_profile=profile,
    capabilities={k: str(v) for k, v in permissions.items()},
    candidates=candidates,
    available_providers=tuple(allowed_providers),
    available_models=tuple(available_models),
)
payload = {
    "model": model,
    "messages": [
        {
            "role": "system",
            "content": (
                "You are a type-safe model-to-work routing decision engine. "
                "Return strictly valid JSON matching the schema."
            ),
        },
        {"role": "user", "content": json.dumps(route_request.to_dict(), sort_keys=True)},
    ],
    "response_format": {
        "type": "json_schema",
        "json_schema": {
            "name": "route_decision",
            "strict": True,
            "schema": agentctl.RouteDecision.json_schema(allowed_providers, available_models or None),
        },
    },
}
api_key_env = router.get("decision_provider", {}).get("api_key_env") or "ROUTER_API_KEY"
api_key = agentctl.os.environ.get(api_key_env, "")
timeout_s = min(max(int(router.get("decision_provider", {}).get("timeout_ms", 5000)) / 1000, 1.0), 15.0)
req = urllib.request.Request(
    f"{base_url}/chat/completions",
    data=json.dumps(payload).encode(),
    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
    method="POST",
)
started = time.monotonic()
try:
    with urllib.request.urlopen(req, timeout=timeout_s) as resp:
        body = json.loads(resp.read(128 * 1024))
except (OSError, ValueError, urllib.error.URLError) as exc:
    print(f"probe request failed: {exc}", file=sys.stderr)
    sys.exit(1)
latency_ms = round((time.monotonic() - started) * 1000, 1)
try:
    decision = agentctl.RouteDecision.from_payload(
        body,
        allowed_providers=set(allowed_providers),
        allowed_models=set(available_models) if available_models else None,
        default_profile=profile,
        default_models=default_models,
        allow_minimal=False,
    )
except (ValueError, KeyError, IndexError, TypeError) as exc:
    print(f"route_decision schema validation failed: {exc}", file=sys.stderr)
    sys.exit(1)
print(json.dumps({
    "latency_ms": latency_ms,
    "provider": decision.provider,
    "model": decision.model,
    "work_type": decision.work_type.value,
    "tier": decision.tier.value,
    "reasoning_effort": decision.reasoning_effort,
    "source": decision.source,
}))
PY
)"; then
    miss "Remote probe failed (see error above)"
    return
  fi

  local probe_summary
  probe_summary="$(printf '%s' "$probe_out" | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
print("latency={}ms selected={}/{} work_type={} tier={} effort={}".format(
    d["latency_ms"], d["provider"], d["model"], d["work_type"], d["tier"], d["reasoning_effort"]))
')"
  ok "Live route_decision probe succeeded: $probe_summary"
}

case "$mode" in
  check)
    run_check
    ;;
  local-only)
    run_local_only
    ;;
  enable-remote)
    run_enable_remote
    ;;
  probe-only)
    ;;
esac

if [ "$do_probe" = 1 ]; then
  run_probe
fi

step "Summary"
if [ "${#todo[@]}" -eq 0 ]; then
  echo "Done. Router setup checks passed."
else
  echo "${#todo[@]} item(s) need attention (see ✘ above)."
  exit 1
fi
