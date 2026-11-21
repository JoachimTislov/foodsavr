#!/usr/bin/env bash
set -euo pipefail

options='lib/firebase_options.dart'
google_services='android/app/src/production/debug/google-services.json'
env_file='assets/.env'

if [ ! -s "$options" ] || grep -q 'not configured\|not configured for fork' "$options"; then
  echo '::error::FIREBASE_OPTIONS_B64 must contain the real test-project configuration for the Drive APK.'
  exit 1
fi

mkdir -p "$(dirname "$google_services")" assets
python3 - "$options" "$google_services" <<'PY'
import json
import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text()
output = Path(sys.argv[2])

def value(name):
    match = re.search(rf"\b{name}\s*(?:[:=])\s*(['\"])(.*?)\1", source)
    if not match or not match.group(2):
        raise SystemExit(f"::error::Firebase options is missing {name}")
    return match.group(2)

project_id = value("projectId")
config = {
    "project_info": {
        "project_number": value("messagingSenderId"),
        "project_id": project_id,
        "storage_bucket": value("storageBucket"),
    },
    "client": [{
        "client_info": {
            "mobilesdk_app_id": value("appId"),
            "android_client_info": {"package_name": "com.foodsavr.app"},
        },
        "oauth_client": [],
        "api_key": [{"current_key": value("apiKey")}],
        "services": {},
    }],
    "configuration_version": "1",
}
output.write_text(json.dumps(config, indent=2) + "\n")
PY

if [ -n "${ANDROID_ENV_B64:-}" ]; then
  if ! printf '%s' "$ANDROID_ENV_B64" | base64 --decode > "$env_file" || [ ! -s "$env_file" ]; then
    echo '::error::ANDROID_ENV_B64 is present but is not valid non-empty base64.'
    exit 1
  fi
elif [ ! -s "$env_file" ]; then
  cat > "$env_file" <<'EOF'
ENVIRONMENT=production
REMA_API_URL=https://api.rema.no
COOP_API_URL=https://api.coop.no
EOF
  echo '::warning::ANDROID_ENV_B64 is missing; using non-secret API endpoint defaults.'
fi
