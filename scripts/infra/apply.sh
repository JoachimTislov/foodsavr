#!/usr/bin/env bash
# Apply infra/terraform with your gcloud login, then publish the outputs as
# GitHub Actions variables. Re-run after any change under infra/terraform.
#
#   GCLOUD_ACCOUNT=you@example.com scripts/infra/apply.sh [plan]
set -euo pipefail

project=my-foodsavr-store
bucket="gs://${project}-tfstate"
dir="$(cd "$(dirname "$0")/../../infra/terraform" && pwd)"
account_args=()
[ -n "${GCLOUD_ACCOUNT:-}" ] && account_args=(--account="$GCLOUD_ACCOUNT")

GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud "${account_args[@]}" auth print-access-token)"
export GOOGLE_OAUTH_ACCESS_TOKEN

# State bucket (one-time; private, versioned).
if ! gcloud "${account_args[@]}" storage buckets describe "$bucket" --project "$project" >/dev/null 2>&1; then
  gcloud "${account_args[@]}" storage buckets create "$bucket" --project "$project" \
    --location=europe-north1 --uniform-bucket-level-access --public-access-prevention
  gcloud "${account_args[@]}" storage buckets update "$bucket" --versioning
fi

terraform -chdir="$dir" init -input=false
if [ "${1:-}" = plan ]; then
  terraform -chdir="$dir" plan -input=false
  exit 0
fi
terraform -chdir="$dir" apply -input=false

if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER --body "$(terraform -chdir="$dir" output -raw workload_identity_provider)"
  gh variable set GCP_DEPLOY_SERVICE_ACCOUNT --body "$(terraform -chdir="$dir" output -raw deploy_service_account)"
  gh variable set RECAPTCHA_ENTERPRISE_SITE_KEY --body "$(terraform -chdir="$dir" output -raw recaptcha_enterprise_site_key)"
  echo "GitHub Actions variables updated."
else
  echo "gh not logged in; set these Actions variables manually:"
  terraform -chdir="$dir" output
fi
