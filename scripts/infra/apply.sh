#!/usr/bin/env bash
# Apply infra/terraform for one environment of the instance declared in
# deploy/instance.yaml (ADR 0005), with your gcloud login, then publish the
# outputs as GitHub Actions variables. Re-run after any change under
# infra/terraform or to the manifest.
#
#   [ENV=production] [MANIFEST=deploy/instance.yaml] [GCLOUD_ACCOUNT=you@example.com] \
#   [BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX] scripts/infra/apply.sh [plan]
#
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

tfvars="$(mktemp --suffix=.tfvars)"
trap 'rm -f "$tfvars"' EXIT
levels env --format tfvars >"$tfvars"
[ -n "${BILLING_ACCOUNT:-}" ] && echo "billing_account = \"$BILLING_ACCOUNT\"" >>"$tfvars"

account_args=()
[ -n "${GCLOUD_ACCOUNT:-}" ] && account_args=(--account="$GCLOUD_ACCOUNT")
GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud "${account_args[@]}" auth print-access-token)"
export GOOGLE_OAUTH_ACCESS_TOKEN

# State bucket (one-time; private, versioned).
bucket="gs://$TF_STATE_BUCKET"
if ! gcloud "${account_args[@]}" storage buckets describe "$bucket" --project "$PROJECT_ID" >/dev/null 2>&1; then
  gcloud "${account_args[@]}" storage buckets create "$bucket" --project "$PROJECT_ID" \
    --location="$REGION" --uniform-bucket-level-access --public-access-prevention
  gcloud "${account_args[@]}" storage buckets update "$bucket" --versioning
fi

terraform -chdir="$dir" init -input=false -reconfigure \
  -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="prefix=$TF_STATE_PREFIX"
if [ "${1:-}" = plan ]; then
  terraform -chdir="$dir" plan -input=false -var-file="$tfvars"
  exit 0
fi
terraform -chdir="$dir" apply -input=false -var-file="$tfvars"

# Per-environment variables: production uses the plain names, others a
# suffix (e.g. GCP_DEPLOY_SERVICE_ACCOUNT_STAGING).
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  out() { terraform -chdir="$dir" output -raw "$1"; }
  gh variable set "GCP_WORKLOAD_IDENTITY_PROVIDER$VAR_SUFFIX" --body "$(out workload_identity_provider)"
  gh variable set "GCP_DEPLOY_SERVICE_ACCOUNT$VAR_SUFFIX" --body "$(out deploy_service_account)"
  gh variable set "RECAPTCHA_ENTERPRISE_SITE_KEY$VAR_SUFFIX" --body "$(out recaptcha_enterprise_site_key)"
  echo "GitHub Actions variables updated ($env_name)."
else
  echo "gh not logged in; set these Actions variables manually (suffix '$VAR_SUFFIX'):"
  terraform -chdir="$dir" output
fi
