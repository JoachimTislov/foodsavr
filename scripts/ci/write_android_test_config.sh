#!/usr/bin/env bash
set -euo pipefail

# Client options come from FIREBASE_DEFINES (JSON; CI: the FIREBASE_DEFINES_TEST
# Actions variable written by setup) or the local defines file; the repository
# tracks no project ids.
defines="$(python3 scripts/firebase_options.py path)"
google_services='android/app/src/production/debug/google-services.json'
env_file='assets/.env'

if [ -n "${FIREBASE_DEFINES:-}" ]; then
  mkdir -p "$(dirname "$defines")"
  printf '%s
' "$FIREBASE_DEFINES" > "$defines"
fi
if ! python3 scripts/firebase_options.py validate "$defines"; then
  echo '::error::Firebase defines for the test project are missing (set FIREBASE_DEFINES_TEST, or run make setup).'
  exit 1
fi

mkdir -p "$(dirname "$google_services")" assets
python3 - "$defines" "$google_services" <<'PY'
import json
import sys
from pathlib import Path

defines = json.loads(Path(sys.argv[1]).read_text())
output = Path(sys.argv[2])
missing = [name for name in ("FIREBASE_ANDROID_APP_ID", "FIREBASE_ANDROID_API_KEY") if not defines.get(name)]
if missing:
    raise SystemExit(f"::error::Firebase defines are missing {', '.join(missing)}")
config = {
    "project_info": {
        "project_number": defines["FIREBASE_MESSAGING_SENDER_ID"],
        "project_id": defines["FIREBASE_PROJECT_ID"],
        "storage_bucket": defines.get("FIREBASE_STORAGE_BUCKET", ""),
    },
    "client": [{
        "client_info": {
            "mobilesdk_app_id": defines["FIREBASE_ANDROID_APP_ID"],
            "android_client_info": {"package_name": "com.foodsavr.app"},
        },
        "oauth_client": [],
        "api_key": [{"current_key": defines["FIREBASE_ANDROID_API_KEY"]}],
        "services": {},
    }],
    "configuration_version": "1",
}
output.write_text(json.dumps(config, indent=2) + "
")
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
