#!/usr/bin/env bash
set -euo pipefail

# One-time setup: authorize gcloud for Drive and provision the repository
# secrets needed by manual-tools.yml (android-drive-test). The APK workflow remains manual.

command -v gcloud >/dev/null || { echo 'gcloud CLI is required.' >&2; exit 1; }
command -v gh >/dev/null || { echo 'GitHub CLI (gh) is required.' >&2; exit 1; }
command -v jq >/dev/null || { echo 'jq is required.' >&2; exit 1; }
command -v curl >/dev/null || { echo 'curl is required.' >&2; exit 1; }

repo="${GH_REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
folder_id="${GOOGLE_DRIVE_FOLDER_ID:-${1:-}}"
scopes='https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/drive'

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

if [ -z "$folder_id" ]; then
  adc_path="${CLOUDSDK_CONFIG:-${HOME}/.config/gcloud}/application_default_credentials.json"
  client_id="$(jq -r '.client_id' "$adc_path")"
  client_secret="$(jq -r '.client_secret' "$adc_path")"
  refresh_token="$(jq -r '.refresh_token' "$adc_path")"
  token_response="$(curl -fsS --retry 2 --data-urlencode "client_id=$client_id" \
    --data-urlencode "client_secret=$client_secret" \
    --data-urlencode "refresh_token=$refresh_token" \
    --data-urlencode 'grant_type=refresh_token' \
    https://oauth2.googleapis.com/token)" || {
    echo 'Google OAuth refresh failed while listing Drive folders.' >&2
    exit 1
  }
  access_token="$(jq -r '.access_token // empty' <<<"$token_response")"
  if [ -z "$access_token" ]; then
    echo 'Google OAuth returned no access token while listing Drive folders.' >&2
    exit 1
  fi
  folders="$(curl -fsS --retry 2 -G \
    -H "Authorization: Bearer $access_token" \
    --data-urlencode "q=mimeType = 'application/vnd.google-apps.folder' and trashed = false" \
    --data-urlencode 'orderBy=name' \
    --data-urlencode 'pageSize=1000' \
    --data-urlencode 'fields=files(id,name)' \
    'https://www.googleapis.com/drive/v3/files')" || {
    echo 'Unable to list Google Drive folders.' >&2
    exit 1
  }
  mapfile -t folder_rows < <(jq -r '.files[]? | [.name, .id] | @tsv' <<<"$folders")
  if [ "${#folder_rows[@]}" -eq 0 ]; then
    echo 'No Google Drive folders were found.' >&2
    exit 1
  fi
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    echo 'GOOGLE_DRIVE_FOLDER_ID is required when setup is not interactive.' >&2
    exit 1
  fi
  echo 'Select the Google Drive destination folder:'
  PS3='Folder number: '
  select row in "${folder_rows[@]}"; do
    if [ -n "${row:-}" ]; then
      folder_id="${row##*$'\t'}"
      break
    fi
    echo 'Choose one of the listed folder numbers.'
  done
fi

if ! [[ "$folder_id" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo 'GOOGLE_DRIVE_FOLDER_ID must be a folder ID, not a URL.' >&2
  exit 1
fi

# Values are piped directly to gh and are never printed or stored in the repo.
printf '%s' "$account" | gh secret set GOOGLE_DRIVE_ACCOUNT --repo "$repo"
printf '%s' "$folder_id" | gh secret set GOOGLE_DRIVE_FOLDER_ID --repo "$repo"
GOOGLE_DRIVE_ACCOUNT="$account" bash scripts/release/set_drive_oauth_secret.sh

echo "Drive deployment secrets configured for $repo. Run the Android Drive workflow manually when ready."
