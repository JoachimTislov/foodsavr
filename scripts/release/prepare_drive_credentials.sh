#!/usr/bin/env bash
set -euo pipefail

drive_scope='https://www.googleapis.com/auth/drive'
output_path="${1:-$PWD/google-drive-oauth.json}"
config_dir="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}"
adc_path="$config_dir/application_default_credentials.json"

command -v gcloud >/dev/null || {
  echo 'gcloud CLI is required.' >&2
  exit 1
}

echo 'Opening Google OAuth with Drive write access...'
gcloud auth application-default login --scopes="$drive_scope"

python3 - "$adc_path" "$output_path" <<'PY'
import json
import os
import sys
from pathlib import Path

source = Path(sys.argv[1])
destination = Path(sys.argv[2]).expanduser()
if not source.is_file():
    raise SystemExit(f'ADC file not found: {source}')
data = json.loads(source.read_text())
required = ('client_id', 'client_secret', 'refresh_token')
if any(not data.get(key) for key in required):
    raise SystemExit('ADC file does not contain a reusable OAuth refresh token.')
scopes = data.get('scopes') or data.get('scope') or ''
if isinstance(scopes, list):
    scopes = ' '.join(scopes)
if 'https://www.googleapis.com/auth/drive' not in scopes:
    print('Warning: ADC did not record the full Drive scope; test the upload before CI.', file=sys.stderr)
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps({key: data[key] for key in required}, separators=(',', ':')) + '\n')
os.chmod(destination, 0o600)
print(f'Wrote Drive OAuth JSON to {destination}')
print('Store its contents as the GOOGLE_DRIVE_OAUTH_JSON GitHub secret.')
PY
