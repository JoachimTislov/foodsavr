#!/usr/bin/env bash
# Apply infra/terraform for one environment of the instance declared in
# deploy/instance.yaml (ADR 0005), with your gcloud login, then publish the
# outputs as GitHub Actions variables. Re-run after any change under
# infra/terraform or to the manifest.
#
#   [ENV=production] [MANIFEST=deploy/instance.yaml] [GCLOUD_ACCOUNT=you@example.com] \
#   [BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX] scripts/infra/apply.sh [plan]
#
# TF_STATE_BACKEND=auto|local|gcs controls state storage (default: auto).
# Auto preserves an existing GCS backend; fresh Spark instances use private
# local state in .deployment-state/<project>/<environment> (back it up).
# BILLING_ACCOUNT is only needed when the environment is on firebase-blaze
# (budget). Linking billing to the project stays a manual owner step.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
dir="$root/infra/terraform"
env_name="${ENV:-production}"
manifest="$(realpath "${MANIFEST:-$root/deploy/instance.yaml}")"

levels() {
  (cd "$root/packages/foodsavr_deploy" && dart pub get >/dev/null &&
    dart run bin/levels.dart "$@" --manifest "$manifest" --env "$env_name")
}

levels validate >&2
# PROJECT_ID, REGION, TF_STATE_*, VAR_SUFFIX, EMULATOR, INFRA_OWNER, ...
eval "$(levels env --format dotenv)"
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
[ -n "${BILLING_ACCOUNT:-}" ] && echo "billing_account = \"$BILLING_ACCOUNT\"" >>"$tfvars"

account_args=()
[ -n "${GCLOUD_ACCOUNT:-}" ] && account_args=(--account="$GCLOUD_ACCOUNT")
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud "${account_args[@]}" auth print-access-token)"
export GOOGLE_OAUTH_ACCESS_TOKEN

# Discover the management key ID, not the API key value. Templates only need
# the project and app IDs; explicitly configured key IDs avoid this lookup.
if [ -z "${WEB_API_KEY_ID:-}" ]; then
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
state_dir="$root/.deployment-state/$PROJECT_ID/$env_name"
state_path="$state_dir/terraform.tfstate"
bucket="gs://$TF_STATE_BUCKET"
bucket_exists=false
if gcloud "${account_args[@]}" storage buckets describe "$bucket" --project "$PROJECT_ID" >"$work/bucket.json" 2>"$work/bucket.error"; then
  bucket_exists=true
elif ! grep -Eq '(^|[^0-9])404([^0-9]|$)|NOT_FOUND' "$work/bucket.error"; then
  echo "Cannot inspect Terraform state bucket; refusing to select a different backend." >&2
  cat "$work/bucket.error" >&2
  exit 1
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
    if [ "${1:-}" = plan ]; then
      echo "GCS state bucket is missing. Provision it before planning, or use TF_STATE_BACKEND=local; plan creates no bucket." >&2
      exit 1
    fi
    gcloud "${account_args[@]}" storage buckets create "$bucket" --project "$PROJECT_ID" \
      --location="$REGION" --uniform-bucket-level-access --public-access-prevention
    gcloud "${account_args[@]}" storage buckets update "$bucket" --versioning
  fi
  backend_args=("-backend-config=bucket=$TF_STATE_BUCKET" "-backend-config=prefix=$TF_STATE_PREFIX")
else
  echo "Using local Terraform state: $state_path. Keep a private backup." >&2
fi
terraform -chdir="$dir" init -input=false "${backend_args[@]}"
if [ "${1:-}" = plan ]; then
  terraform -chdir="$dir" plan -input=false -var-file="$tfvars"
  exit 0
fi
terraform -chdir="$dir" apply -input=false -var-file="$tfvars"

# Per-environment variables: production uses the plain names, others a
# suffix (e.g. GCP_DEPLOY_SERVICE_ACCOUNT_STAGING).
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  out() { terraform -chdir="$dir" output -raw "$1"; }
  gh variable set --repo "$GITHUB_REPOSITORY" "GCP_WORKLOAD_IDENTITY_PROVIDER$VAR_SUFFIX" --body "$(out workload_identity_provider)"
  gh variable set --repo "$GITHUB_REPOSITORY" "GCP_DEPLOY_SERVICE_ACCOUNT$VAR_SUFFIX" --body "$(out deploy_service_account)"
  gh variable set --repo "$GITHUB_REPOSITORY" "RECAPTCHA_ENTERPRISE_SITE_KEY$VAR_SUFFIX" --body "$(out recaptcha_enterprise_site_key)"
  echo "GitHub Actions variables updated ($env_name)."
else
  echo "gh not logged in; set these Actions variables manually (suffix '$VAR_SUFFIX'):"
  terraform -chdir="$dir" output
fi
