#!/usr/bin/env bash
set -euo pipefail

# Copy the currently configured gcloud user OAuth credentials into GitHub
# without writing the refresh token to the repository or to a local output file.

command -v gcloud >/dev/null || { echo 'gcloud CLI is required.' >&2; exit 1; }
command -v gh >/dev/null || { echo 'GitHub CLI (gh) is required.' >&2; exit 1; }
command -v jq >/dev/null || { echo 'jq is required.' >&2; exit 1; }
command -v curl >/dev/null || { echo 'curl is required.' >&2; exit 1; }

adc_path="${CLOUDSDK_CONFIG:-${HOME}/.config/gcloud}/application_default_credentials.json"
repo="${GH_REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
expected_account="${GOOGLE_DRIVE_ACCOUNT:-}"

if [ ! -r "$adc_path" ]; then
  echo "Application Default Credentials not found: $adc_path" >&2
  echo 'Run gcloud auth application-default login with Drive access first.' >&2
  exit 1
fi

account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n 1)"
account="${account:-$(jq -r '.account // empty' "$adc_path")}" 
if [ -n "$expected_account" ] && [ "$account" != "$expected_account" ]; then
  echo "Active gcloud account is $account, expected $expected_account." >&2
  exit 1
fi

if ! jq -e '
  (.client_id | type == "string" and length > 0) and
  (.client_secret | type == "string" and length > 0) and
  (.refresh_token | type == "string" and length > 0)
' "$adc_path" >/dev/null; then
  echo 'ADC does not contain a reusable OAuth client ID, client secret and refresh token.' >&2
  exit 1
fi

client_id="$(jq -r '.client_id' "$adc_path")"
client_secret="$(jq -r '.client_secret' "$adc_path")"
refresh_token="$(jq -r '.refresh_token' "$adc_path")"

# Verify that the refresh token can access Drive before changing the GitHub secret.
token_response="$(curl -fsS --retry 2 --data-urlencode "client_id=$client_id" \
  --data-urlencode "client_secret=$client_secret" \
  --data-urlencode "refresh_token=$refresh_token" \
  --data-urlencode 'grant_type=refresh_token' \
  https://oauth2.googleapis.com/token)" || {
  echo 'Google OAuth refresh failed; reauthorize gcloud with Drive access.' >&2
  exit 1
}
access_token="$(jq -r '.access_token // empty' <<<"$token_response")"
if [ -z "$access_token" ]; then
  echo 'Google OAuth returned no access token; reauthorize gcloud with Drive access.' >&2
  exit 1
fi
if ! curl -fsS -o /dev/null -H "Authorization: Bearer $access_token" \
  'https://www.googleapis.com/drive/v3/about?fields=user(emailAddress)'; then
  echo 'The OAuth grant cannot access Drive. Reauthorize with the Drive scope.' >&2
  exit 1
fi

# gh reads the secret value from stdin; the JSON never appears in shell history.
jq -c '{client_id,client_secret,refresh_token}' "$adc_path" \
  | gh secret set GOOGLE_DRIVE_OAUTH_JSON --repo "$repo"

echo "Set GOOGLE_DRIVE_OAUTH_JSON for $repo using the configured gcloud account."
