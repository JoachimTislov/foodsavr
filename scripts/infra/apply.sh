#!/usr/bin/env bash
# Apply infra/terraform/gcp for one environment of the instance declared in
# deploy/instance.yaml (ADR 0005, ADR 0008), with your gcloud login, then
# publish the outputs as GitHub Actions variables. Re-run after any change under
# infra/terraform/gcp or to the manifest.
#
#   [ENV=production] [MANIFEST=deploy/instance.yaml] [GCLOUD_ACCOUNT=you@example.com] \
#   [BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX] [RELEASE_TOPOLOGY=full-channels] \
#   [PLAN_OUT=/path/to/gcp.tfplan] scripts/infra/apply.sh [plan]
#
# TF_STATE_BACKEND=auto|local|gcs controls state storage (default: auto).
# Auto preserves an existing GCS backend; fresh Spark instances use worktree-safe
# local state under ${XDG_STATE_HOME:-$HOME/.local/state}/foodsavr/terraform/<owner>/<repo>/gcp-<project>-<env>/terraform.tfstate.
# BILLING_ACCOUNT is only needed when the environment is on firebase-blaze
# (budget). Linking billing to the project stays a manual owner step.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
dir="$root/infra/terraform/gcp"
env_name="${ENV:-production}"
action="${1:-apply}"
case "$action" in plan|apply|show) ;; *) echo "Usage: $0 [plan|apply|show]" >&2; exit 2 ;; esac
target_repo="${GITHUB_REPOSITORY:-}"
manifest="$(realpath "${MANIFEST:-$root/deploy/instance.yaml}")"

levels() {
  (cd "$root/packages/foodsavr_deploy" && dart pub get >/dev/null &&
    dart run bin/levels.dart "$@" --manifest "$manifest" --env "$env_name")
}

levels validate >&2
# PROJECT_ID, REGION, TF_STATE_*, VAR_SUFFIX, EMULATOR, INFRA_OWNER, GITHUB_REPOSITORY, GH_ENVIRONMENT, ...
eval "$(levels env --format dotenv)"
if [ -n "$target_repo" ] && [ "$target_repo" != "$GITHUB_REPOSITORY" ]; then
  echo "Choose a deployment manifest for $target_repo before configuring Firebase." >&2
  exit 1
fi
if [ "$EMULATOR" = true ]; then
  echo "Environment $env_name runs on emulators; nothing to apply." >&2
  exit 0
fi
if [ "$INFRA_OWNER" != "$env_name" ]; then
  echo "Environment $env_name shares $INFRA_OWNER's project; apply ENV=$INFRA_OWNER instead." >&2
  exit 1
fi

umask 077
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
tfvars="$work/instance.tfvars"
levels env --format tfvars >"$tfvars"
[ -n "${BILLING_ACCOUNT:-}" ] && printf 'billing_account = "%s"\n' "$BILLING_ACCOUNT" >>"$tfvars"
gh_env="${GH_ENVIRONMENT:-$env_name}"
printf 'github_environment = "%s"\n' "$gh_env" >>"$tfvars"
topology="${RELEASE_TOPOLOGY:-full-channels}"
branches="$(python3 "$root/scripts/setup/setupctl.py" topology "$topology")"
integration_branch="$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])[0])' "$branches")"
deploy_branch="${DEPLOY_BRANCH:-$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])[-1])' "$branches")}"
printf 'release_topology = "%s"\ndeploy_branch = "%s"\ntelemetry_branch = "%s"\n' \
  "$topology" "$deploy_branch" "$integration_branch" >>"$tfvars"
[ -n "${ALLOW_PREVIEW_REFS:-}" ] && printf 'allow_preview_refs = %s\n' "$ALLOW_PREVIEW_REFS" >>"$tfvars"

account_args=()
[ -n "${GCLOUD_ACCOUNT:-}" ] && account_args=(--account="$GCLOUD_ACCOUNT")
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud "${account_args[@]}" auth print-access-token)"
export GOOGLE_OAUTH_ACCESS_TOKEN

# Discover the management key ID, not the API key value. Templates only need
# the project and app IDs; explicitly configured key IDs avoid this lookup.
if [ -z "${WEB_API_KEY_ID:-}" ] && [ "$action" != show ] && [ -z "${PLAN_FILE:-}" ]; then
  export PROJECT_ID WEB_APP_ID
  WEB_API_KEY_ID="$(python3 "$root/scripts/infra/bootstrap_support.py" api-key)"
  printf 'web_api_key_id = "%s"\n' "$WEB_API_KEY_ID" >>"$tfvars"
fi

# A failed permission/network check must not be mistaken for a missing
# bucket: otherwise Terraform could start with empty state and recreate infra.
backend="${TF_STATE_BACKEND:-auto}"
case "$backend" in auto|local|gcs) ;; *) echo "TF_STATE_BACKEND must be auto, local or gcs." >&2; exit 1 ;; esac
if [[ ! "$PROJECT_ID" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
  echo "PROJECT_ID must be a project ID without path separators." >&2
  exit 1
fi

repo_slug="${GITHUB_REPOSITORY:-local/foodsavr}"
state_path="$(python3 "$root/scripts/infra/bootstrap_support.py" state-path "$repo_slug" "gcp-$PROJECT_ID-$env_name")"
state_dir="$(dirname "$state_path")"
legacy_state_path="$root/.deployment-state/$PROJECT_ID/$env_name/terraform.tfstate"

if [ -f "$legacy_state_path" ]; then
  if [ -f "$state_path" ]; then
    echo "Both legacy state ($legacy_state_path) and XDG state ($state_path) exist. Reconcile them manually before running." >&2
    exit 1
  fi
  echo "Legacy local Terraform state found at $legacy_state_path." >&2
  echo "Move it outside the git worktree first to avoid losing state:" >&2
  echo "  mkdir -p \"$state_dir\" && mv \"$legacy_state_path\" \"$state_path\"" >&2
  exit 1
fi

# This project's state from before it was renamed to a non-production
# environment (for example the test project, #454) must not be left behind.
if [ "$env_name" != production ] && [ ! -f "$state_path" ]; then
  renamed_state_path="$(python3 "$root/scripts/infra/bootstrap_support.py" state-path "$repo_slug" "gcp-$PROJECT_ID-production")"
  if [ -f "$renamed_state_path" ]; then
    echo "Terraform state of $PROJECT_ID is still stored under its production name: $renamed_state_path." >&2
    echo "Move it to the $env_name name first (make setup does this), so the apply does not start from empty state:" >&2
    echo "  mkdir -p \"$state_dir\" && mv \"$renamed_state_path\" \"$state_path\"" >&2
    exit 1
  fi
fi

bucket="gs://$TF_STATE_BUCKET"
bucket_exists=false
billing_fallback=false
if gcloud "${account_args[@]}" storage buckets describe "$bucket" --project "$PROJECT_ID" >"$work/bucket.json" 2>"$work/bucket.error"; then
  bucket_exists=true
elif ! grep -Eq '(^|[^0-9])404([^0-9]|$)|NOT_FOUND' "$work/bucket.error"; then
  if [[ "$backend" != gcs && "$DEPLOYMENT_LEVEL" == firebase-spark ]] &&
    grep -Eiq '403|PERMISSION_DENIED' "$work/bucket.error" &&
    { grep -Eiq 'accountDisabled|billing.*(disabled|not enabled|not linked|closed)' "$work/bucket.error" ||
      [[ "$(gcloud "${account_args[@]}" billing projects describe "$PROJECT_ID" --format='value(billingEnabled)' 2>/dev/null)" =~ ^([Ff]alse)$ ]]; }; then
    billing_fallback=true
  else
    echo "Cannot inspect Terraform state bucket; refusing to select a different backend." >&2
    cat "$work/bucket.error" >&2
    exit 1
  fi
fi

if [ "$backend" = auto ]; then
  if [ -f "$state_path" ] && [ "$bucket_exists" = true ]; then
    echo "Both local state and a GCS bucket exist. Choose TF_STATE_BACKEND explicitly after checking state; no migration is automatic." >&2
    exit 1
  elif [ -f "$state_path" ]; then
    backend=local
  elif [ "$bucket_exists" = true ]; then
    backend=gcs
  elif [ "$DEPLOYMENT_LEVEL" = firebase-spark ]; then
    backend=local
  else
    backend=gcs
  fi
fi
if [ "$backend" = gcs ] && [ -f "$state_path" ]; then
  echo "Local Terraform state exists at $state_path. Migrate it explicitly before choosing GCS." >&2
  exit 1
fi
if [ "$backend" = local ] && [ "$bucket_exists" = true ]; then
  echo "A remote state bucket exists. Refusing a local backend that could lose existing resource ownership." >&2
  exit 1
fi

mkdir -p "$state_dir" "$work/config"
python3 "$root/scripts/infra/bootstrap_support.py" config "$dir" "$work/config" "$backend" "$state_path"
dir="$work/config"
backend_args=()
if [ "$backend" = gcs ]; then
  if [ "$bucket_exists" != true ]; then
    if [ "$DEPLOYMENT_LEVEL" = firebase-spark ]; then
      echo "Spark bootstrap cannot create GCS buckets without billing. Use TF_STATE_BACKEND=local." >&2
      exit 1
    fi
    if [ "$action" != apply ] || [ -n "${PLAN_FILE:-}" ]; then
      echo "GCS state bucket is missing. Provision it before planning, or use TF_STATE_BACKEND=local; plan creates no bucket." >&2
      exit 1
    fi
    gcloud "${account_args[@]}" storage buckets create "$bucket" --project "$PROJECT_ID" \
      --location="$REGION" --uniform-bucket-level-access --public-access-prevention
    gcloud "${account_args[@]}" storage buckets update "$bucket" --versioning
  fi
  backend_args=("-backend-config=bucket=$TF_STATE_BUCKET" "-backend-config=prefix=$TF_STATE_PREFIX")
  # Same guard as for local state: a project renamed from production keeps its
  # remote state under the old `firebase` prefix until it is copied.
  if [ "$bucket_exists" = true ] && [ "$env_name" != production ] && [ "$TF_STATE_PREFIX" != firebase ]; then
    # 0: the object exists; 1: it is missing; anything else is a failed lookup.
    state_object() {
      if gcloud "${account_args[@]}" storage ls "$1" >/dev/null 2>"$work/state-object.error"; then
        return 0
      elif grep -qi 'matched no objects' "$work/state-object.error"; then
        return 1
      fi
      echo "Cannot inspect remote state $1; refusing to start from empty state." >&2
      cat "$work/state-object.error" >&2
      exit 1
    }
    if ! state_object "$bucket/$TF_STATE_PREFIX/default.tfstate" && state_object "$bucket/firebase/default.tfstate"; then
      echo "Remote Terraform state of $PROJECT_ID is still under its production prefix: $bucket/firebase." >&2
      echo "Copy it to the $env_name prefix first, so the apply does not start from empty state:" >&2
      echo "  gcloud storage cp $bucket/firebase/default.tfstate $bucket/$TF_STATE_PREFIX/default.tfstate" >&2
      exit 1
    fi
  fi
else
  echo "Using local Terraform state: $state_path. Keep a private backup." >&2
fi
terraform -chdir="$dir" init -input=false "${backend_args[@]}"
if [ "$action" = show ]; then
  terraform -chdir="$dir" show -no-color "${PLAN_FILE:?Set PLAN_FILE}"
  exit 0
fi

recovery=false
if [ "$backend" = local ] && { [ "$billing_fallback" = true ] || [ -f "$state_dir/adopt-local" ]; }; then
  recovery=true
fi
if [ "$recovery" = true ] && [ -z "${PLAN_FILE:-}" ]; then
  deploy_account="$(python3 "$root/scripts/infra/adopt.py" gcp "$dir" "$PROJECT_ID" "$WEB_APP_ID" \
    "$GITHUB_REPOSITORY" "$gh_env" "$deploy_branch" "$integration_branch" \
    "${ALLOW_PREVIEW_REFS:-false}" "$DEPLOYMENT_LEVEL" "${BILLING_ACCOUNT:-}" "${GCLOUD_ACCOUNT:-}")"
  printf 'deploy_service_account_id = "%s"\nlocal_recovery = true\n' "$deploy_account" >>"$tfvars"
fi

if [ "$action" = plan ]; then
  plan_args=()
  [ -n "${PLAN_OUT:-}" ] && plan_args=("-out=$PLAN_OUT")
  [ "${TF_DETAILED_EXITCODE:-}" = 1 ] && plan_args+=("-detailed-exitcode")
  terraform -chdir="$dir" plan -input=false -var-file="$tfvars" "${plan_args[@]}"
  exit 0
fi
if [ "$recovery" = true ] && [ -z "${PLAN_FILE:-}" ]; then
  PLAN_FILE="$work/local.tfplan"
  terraform -chdir="$dir" plan -input=false -var-file="$tfvars" -out="$PLAN_FILE"
  terraform -chdir="$dir" show -no-color "$PLAN_FILE"
  read -r -p "Apply this local recovery plan? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi

if [ -n "${PLAN_FILE:-}" ]; then
  recovery="$(terraform -chdir="$dir" show -json "$PLAN_FILE" | python3 "$root/scripts/infra/adopt.py" safe-plan "$recovery")"
  if [ "$recovery" = true ]; then
    if [ "$backend" != local ]; then
      echo "A local recovery plan requires the local state backend." >&2
      exit 1
    fi
    # Keep recovery active across interrupted applies and subsequent runs.
    touch "$state_dir/adopt-local"
  fi
  terraform -chdir="$dir" apply "$PLAN_FILE"
else
  terraform -chdir="$dir" apply -var-file="$tfvars"
fi

# Per-environment variables: production uses the plain names, others a
# suffix (e.g. GCP_DEPLOY_SERVICE_ACCOUNT_STAGING).
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  out() { terraform -chdir="$dir" output -raw "$1"; }
  wif_provider="$(out workload_identity_provider)"
  deploy_sa="$(out deploy_service_account)"
  telemetry_sa="$(out telemetry_service_account)"
  recaptcha_key="$(out recaptcha_enterprise_site_key)"

  gh variable set --repo "$GITHUB_REPOSITORY" "GCP_WORKLOAD_IDENTITY_PROVIDER$VAR_SUFFIX" --body "$wif_provider"
  gh variable set --repo "$GITHUB_REPOSITORY" "GCP_DEPLOY_SERVICE_ACCOUNT$VAR_SUFFIX" --body "$deploy_sa"
  gh variable set --repo "$GITHUB_REPOSITORY" "GCP_TELEMETRY_SERVICE_ACCOUNT$VAR_SUFFIX" --body "$telemetry_sa"
  gh variable set --repo "$GITHUB_REPOSITORY" "RECAPTCHA_ENTERPRISE_SITE_KEY$VAR_SUFFIX" --body "$recaptcha_key"

  # Also sync live WIF outputs onto the GitHub Environment if it already exists.
  if gh api "repos/$GITHUB_REPOSITORY/environments/$gh_env" >/dev/null 2>&1; then
    gh variable set --repo "$GITHUB_REPOSITORY" --env "$gh_env" "GCP_WORKLOAD_IDENTITY_PROVIDER" --body "$wif_provider"
    gh variable set --repo "$GITHUB_REPOSITORY" --env "$gh_env" "GCP_DEPLOY_SERVICE_ACCOUNT" --body "$deploy_sa"
  fi
  echo "GitHub Actions variables updated ($env_name)."
else
  echo "gh not logged in; set these Actions variables manually (suffix '$VAR_SUFFIX'):"
  terraform -chdir="$dir" output
fi
