#!/usr/bin/env bash
set -euo pipefail

# One-time setup: authorize gcloud for Drive and provision the repository
# secrets needed by android-drive-test.yml. The APK workflow remains manual.

command -v gcloud >/dev/null || { echo 'gcloud CLI is required.' >&2; exit 1; }
command -v gh >/dev/null || { echo 'GitHub CLI (gh) is required.' >&2; exit 1; }
command -v jq >/dev/null || { echo 'jq is required.' >&2; exit 1; }

repo="${GH_REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
folder_id="${GOOGLE_DRIVE_FOLDER_ID:-${1:-}}"
scopes='https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/drive'

if [ -z "$folder_id" ]; then
  echo 'GOOGLE_DRIVE_FOLDER_ID is required (pass it as the first argument or environment variable).' >&2
  exit 1
fi
if ! [[ "$folder_id" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo 'GOOGLE_DRIVE_FOLDER_ID must be a folder ID, not a URL.' >&2
  exit 1
fi

login_args=(auth application-default login --scopes="$scopes")
if [ -n "${GOOGLE_OAUTH_CLIENT_ID_FILE:-}" ]; then
  login_args+=(--client-id-file="$GOOGLE_OAUTH_CLIENT_ID_FILE")
fi
gcloud "${login_args[@]}"

account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n 1)"
if [ -z "$account" ]; then
  echo 'No active gcloud account was found.' >&2
  exit 1
fi

# Values are piped directly to gh and are never printed or stored in the repo.
printf '%s' "$account" | gh secret set GOOGLE_DRIVE_ACCOUNT --repo "$repo"
printf '%s' "$folder_id" | gh secret set GOOGLE_DRIVE_FOLDER_ID --repo "$repo"
GOOGLE_DRIVE_ACCOUNT="$account" bash scripts/release/set_drive_oauth_secret.sh

echo "Drive deployment secrets configured for $repo. Run the Android Drive workflow manually when ready."
