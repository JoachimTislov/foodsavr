#!/usr/bin/env bash
# Idempotent setup for Google and Facebook sign-in (Firebase Auth, Android + Web).
#
# Usage: scripts/setup/social_auth.sh [--check]
#   --check   report what is missing without changing anything.
# Exits 1 while anything besides the manual Meta console check is missing.
# Console-only steps (copying secrets, Meta settings) are human scripts, run first:
#   scripts/human/meta/create-app-credentials.sh   (rotate: rotate-app-secret.sh)
#   scripts/human/google/create-web-client-secret.sh (rotate: rotate-web-client-secret.sh)
#
# Inputs (environment or repo-root .env):
#   FIREBASE_PROJECT          default: my-foodsavr-store
#   FACEBOOK_APP_ID           Meta app ID
#   FACEBOOK_APP_SECRET       Meta app secret (Firebase provider + Graph API)
#   FACEBOOK_CLIENT_TOKEN     Meta client token (Android SDK)
#   GOOGLE_WEB_CLIENT_SECRET  secret of the "Web client (auto created by Google
#                             Service)"; only needed to enable Google via API
#   AUTH_DOMAINS              comma-separated extra Firebase authorized domains
#   EXTRA_SHA                 comma-separated extra SHA-1/SHA-256 (e.g. Play signing)
#   ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS
#                             release keystore (or android/key.properties)
#   SET_GITHUB_SECRETS=1      also push FACEBOOK_APP_ID/CLIENT_TOKEN via scripts/secrets/rotate.py
#
# Requires: firebase (or npx), gcloud, keytool, curl, python3; gh is optional.
# The gcloud account needs roles/firebaseauth.admin and
# roles/serviceusage.serviceUsageConsumer on the project.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

check_only=0
[ "${1:-}" = "--check" ] && check_only=1

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

project="${FIREBASE_PROJECT:-my-foodsavr-store}"
graph="https://graph.facebook.com/v21.0"
idt="https://identitytoolkit.googleapis.com/admin/v2/projects/$project"
todo=()

ok() { printf '  \033[32m✔\033[0m %s\n' "$1"; }
miss() { printf '  \033[33m✘\033[0m %s\n' "$1"; todo+=("$1"); }
note() { printf '  \033[36m•\033[0m %s\n' "$1"; }
failed() { [ -z "$1" ] || printf '%s' "$1" | grep -q '"error"'; }
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }
json() { python3 -I -c "import json,sys; d=json.load(sys.stdin); $1"; }
if command -v firebase >/dev/null; then
  firebase_bin=(firebase)
else
  firebase_bin=(npx -y firebase-tools@latest)
fi
firebase_cli() { "${firebase_bin[@]}" --project "$project" "$@"; }

for tool in gcloud keytool curl python3; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done

step "Access"
token="$(gcloud auth print-access-token 2>/dev/null || true)"
# Secrets never go through argv: the token goes in a curl config and request
# bodies through process substitution (printf is a shell builtin).
api() {
  local method="$1" url="$2" body="${3:-}" args=()
  [ -n "$body" ] && args=(--data-binary @<(printf '%s' "$body"))
  curl -sS -X "$method" "$url" \
    -K <(printf 'header = "Authorization: Bearer %s"\n' "$token") \
    -H "x-goog-user-project: $project" \
    -H 'Content-Type: application/json' \
    "${args[@]}"
}
auth_config=""
if [ -n "$token" ]; then
  auth_config="$(api GET "$idt/config")"
fi
if [ -z "$auth_config" ] || printf '%s' "$auth_config" | grep -q '"error"'; then
  account="$(gcloud config get-value account 2>/dev/null || echo '<account>')"
  miss "gcloud cannot manage Firebase Auth. Run:
      gcloud projects add-iam-policy-binding $project --member=user:$account --role=roles/firebaseauth.admin
      gcloud projects add-iam-policy-binding $project --member=user:$account --role=roles/serviceusage.serviceUsageConsumer"
  auth_config=""
else
  ok "gcloud can manage Firebase Auth for $project"
fi

step "Android SHA fingerprints"
fingerprints() { # keystore storepass alias -> "sha1 sha256" lines (lowercase hex)
  KEYSTORE_PASS="$2" keytool -list -v -keystore "$1" -storepass:env KEYSTORE_PASS -alias "$3" 2>/dev/null |
    awk '/SHA1:|SHA256:/ {gsub(":", "", $2); print tolower($2)}'
}
shas=()
if [ -f "$HOME/.android/debug.keystore" ]; then
  mapfile -t -O "${#shas[@]}" shas < <(fingerprints "$HOME/.android/debug.keystore" android androiddebugkey)
fi
release_store="${ANDROID_KEYSTORE_PATH:-}"
release_pass="${ANDROID_KEYSTORE_PASSWORD:-}"
release_alias="${ANDROID_KEY_ALIAS:-}"
if [ -z "$release_store" ] && [ -f android/key.properties ]; then
  prop() { sed -n "s/^$1=//p" android/key.properties | head -1; }
  release_store="$(prop storeFile)"
  release_pass="$(prop storePassword)"
  release_alias="$(prop keyAlias)"
  case "$release_store" in /*) ;; *) release_store="android/app/$release_store" ;; esac
fi
if [ -n "$release_store" ] && [ -f "$release_store" ]; then
  mapfile -t -O "${#shas[@]}" shas < <(fingerprints "$release_store" "$release_pass" "$release_alias")
else
  miss "No release keystore found (android/key.properties or ANDROID_KEYSTORE_PATH); release builds cannot use Google sign-in"
fi
IFS=',' read -r -a extra <<<"${EXTRA_SHA:-}"
for sha in "${extra[@]}"; do
  [ -n "$sha" ] && shas+=("$(printf '%s' "$sha" | tr -d ':' | tr '[:upper:]' '[:lower:]')")
done

mapfile -t app_ids < <(firebase_cli apps:list ANDROID --json 2>/dev/null |
  json "[print(a['appId']) for a in d.get('result', [])]")
[ "${#app_ids[@]}" -gt 0 ] || { echo "No Android apps found in $project" >&2; exit 1; }

changed_shas=0
for app in "${app_ids[@]}"; do
  existing="$(firebase_cli apps:android:sha:list "$app" --json 2>/dev/null |
    json "[print(c['shaHash'].lower()) for c in d.get('result', [])]" || true)"
  for sha in "${shas[@]}"; do
    if grep -qx "$sha" <<<"$existing"; then
      ok "$app has ${sha:0:12}…"
    elif [ "$check_only" = 1 ]; then
      miss "$app is missing SHA ${sha:0:12}…"
    else
      firebase_cli apps:android:sha:create "$app" "$sha" >/dev/null
      ok "$app registered ${sha:0:12}…"
      changed_shas=1
    fi
  done
done

step "google-services.json"
target="android/app/google-services.json"
if [ "$check_only" = 0 ] && { [ "$changed_shas" = 1 ] || [ ! -f "$target" ]; }; then
  tmp="$(mktemp -d)/google-services.json"
  if firebase_cli apps:sdkconfig ANDROID "${app_ids[0]}" --out "$tmp" >/dev/null 2>&1 &&
    json "assert d['client']" <"$tmp" 2>/dev/null; then
    mv "$tmp" "$target"
    ok "Wrote $target"
  else
    miss "Could not download $target"
  fi
  rm -rf "$(dirname "$tmp")"
fi
if [ -f "$target" ]; then
  android_clients="$(json "print(sum(1 for c in d['client'] for o in c.get('oauth_client', []) if o.get('client_type') == 1))" <"$target")"
  if [ "$android_clients" -gt 0 ]; then
    ok "$target has $android_clients Android OAuth client(s)"
  else
    miss "$target has no Android OAuth clients; re-run after SHA registration"
  fi
  web_client_id="$(json "print(next((o['client_id'] for c in d['client'] for o in c.get('oauth_client', []) if o.get('client_type') == 3), ''))" <"$target")"
  if [ -n "$web_client_id" ]; then
    ok "$target has a web OAuth client (google_sign_in needs it on Android)"
  else
    miss "$target has no web OAuth client; enable Google sign-in in Firebase, then re-run"
  fi
else
  miss "$target is missing; run without --check to download it"
fi

step "Firebase Auth providers"
provider() { # idp clientId clientSecret
  local idp="$1" id="$2" secret="$3" current enabled
  current="$(api GET "$idt/defaultSupportedIdpConfigs/$idp")"
  if failed "$current" && ! printf '%s' "$current" | grep -q '"NOT_FOUND"'; then
    miss "Could not read the $idp provider config"
    return
  fi
  enabled="$(printf '%s' "$current" | json "print(str(d.get('enabled', False)).lower())")"
  if [ "$enabled" = true ]; then
    ok "$idp is enabled"
  elif [ -z "$id" ] || [ -z "$secret" ]; then
    case "$idp" in
      google.com) miss "$idp is disabled; run scripts/human/google/create-web-client-secret.sh, then re-run" ;;
      *) miss "$idp is disabled; run scripts/human/meta/create-app-credentials.sh, then re-run" ;;
    esac
  elif [ "$check_only" = 1 ]; then
    miss "$idp is disabled"
  else
    local body result
    body="$(IDP_ID="$id" IDP_SECRET="$secret" python3 -I -c 'import json,os; print(json.dumps({"enabled": True, "clientId": os.environ["IDP_ID"], "clientSecret": os.environ["IDP_SECRET"]}))')"
    if printf '%s' "$current" | grep -q '"NOT_FOUND"'; then
      result="$(api POST "$idt/defaultSupportedIdpConfigs?idpId=$idp" "$body")"
    else
      result="$(api PATCH "$idt/defaultSupportedIdpConfigs/$idp?updateMask=enabled,clientId,clientSecret" "$body")"
    fi
    if failed "$result"; then
      miss "Enabling $idp failed"
    else
      ok "$idp enabled"
    fi
  fi
}
if [ -n "$auth_config" ]; then
  provider google.com "${web_client_id:-}" "${GOOGLE_WEB_CLIENT_SECRET:-}"
  provider facebook.com "${FACEBOOK_APP_ID:-}" "${FACEBOOK_APP_SECRET:-}"

  IFS=',' read -r -a wanted <<<"${AUTH_DOMAINS:-}"
  domains="$(printf '%s' "$auth_config" | json "print('\n'.join(d.get('authorizedDomains', [])))")"
  missing_domains=()
  for domain in "${wanted[@]}"; do
    [ -z "$domain" ] && continue
    grep -qx "$domain" <<<"$domains" && ok "Authorized domain $domain" || missing_domains+=("$domain")
  done
  if [ "${#missing_domains[@]}" -gt 0 ]; then
    if [ "$check_only" = 1 ]; then
      miss "Authorized domains missing: ${missing_domains[*]}"
    else
      body="$(printf '%s\n' "$domains" "${missing_domains[@]}" |
        python3 -I -c 'import json,sys; print(json.dumps({"authorizedDomains": [l for l in sys.stdin.read().split() if l]}))')"
      if failed "$(api PATCH "$idt/config?updateMask=authorizedDomains" "$body")"; then
        miss "Adding authorized domains failed: ${missing_domains[*]}"
      else
        ok "Added authorized domains: ${missing_domains[*]}"
      fi
    fi
  fi
fi

step "Meta app"
redirect_uri="https://$project.firebaseapp.com/__/auth/handler"
key_hashes=()
for sha in "${shas[@]}"; do
  [ "${#sha}" = 40 ] && key_hashes+=("$(python3 -I -c 'import base64,sys; print(base64.b64encode(bytes.fromhex(sys.argv[1])).decode())' "$sha")")
done
if [ -z "${FACEBOOK_APP_ID:-}" ] || [ -z "${FACEBOOK_APP_SECRET:-}" ]; then
  miss "FACEBOOK_APP_ID/FACEBOOK_APP_SECRET missing; run scripts/human/meta/create-app-credentials.sh"
else
  app_token="$FACEBOOK_APP_ID|$FACEBOOK_APP_SECRET"
  app_meta="$(curl -sS -G "$graph/$FACEBOOK_APP_ID" --data-urlencode "fields=android_key_hash" \
    --data-urlencode "access_token@"<(printf '%s' "$app_token") || true)"
  current_hashes=""
  failed "$app_meta" ||
    current_hashes="$(printf '%s' "$app_meta" | json "print('\n'.join(d.get('android_key_hash', [])))")"
  missing_hashes=()
  for h in "${key_hashes[@]}"; do grep -qxF "$h" <<<"$current_hashes" || missing_hashes+=("$h"); done
  if failed "$app_meta"; then
    # Never overwrite the list when it could not be read.
    miss "Meta Graph API could not read the app; add key hashes manually: ${key_hashes[*]}"
  elif [ "${#missing_hashes[@]}" = 0 ]; then
    ok "Meta app has all Android key hashes"
  elif [ "$check_only" = 1 ]; then
    miss "Meta app is missing key hashes: ${missing_hashes[*]}"
  else
    all="$(printf '%s\n' "$current_hashes" "${missing_hashes[@]}" |
      python3 -I -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().split() if l]))')"
    result="$(curl -sS -X POST "$graph/$FACEBOOK_APP_ID" --data-urlencode "android_key_hash=$all" \
      --data-urlencode "access_token@"<(printf '%s' "$app_token"))"
    if printf '%s' "$result" | grep -q '"success": *true'; then
      ok "Meta app key hashes updated"
    else
      miss "Meta API rejected key hashes; add manually: ${missing_hashes[*]}"
    fi
  fi
fi
note "Meta console (manual, check once): scripts/human/meta/create-app-credentials.sh stage 3
      (redirect URI $redirect_uri, Android packages, Live mode)"

step "Facebook client config"
for name in FACEBOOK_APP_ID FACEBOOK_CLIENT_TOKEN; do
  if [ -z "${!name:-}" ]; then
    miss "$name is not set; run scripts/human/meta/create-app-credentials.sh"
  else
    ok "$name is set"
  fi
done
# Secrets only change through the rotate script (see AGENTS.md).
if [ "${SET_GITHUB_SECRETS:-0}" = 1 ] && [ "$check_only" = 0 ]; then
  if [ ! -x scripts/secrets/rotate.py ]; then
    miss "scripts/secrets/rotate.py is missing; cannot set GitHub secrets"
  elif NEW_FACEBOOK_APP_ID="${FACEBOOK_APP_ID:-}" NEW_FACEBOOK_CLIENT_TOKEN="${FACEBOOK_CLIENT_TOKEN:-}" \
    scripts/secrets/rotate.py FACEBOOK_APP_ID FACEBOOK_CLIENT_TOKEN </dev/null; then
    ok "Facebook client values pushed via scripts/secrets/rotate.py"
  else
    miss "scripts/secrets/rotate.py failed for FACEBOOK_APP_ID/FACEBOOK_CLIENT_TOKEN"
  fi
fi

step "Summary"
if [ "${#todo[@]}" -eq 0 ]; then
  echo "Done. Only the one-time Meta console check (•) remains."
else
  echo "${#todo[@]} item(s) need attention (see ✘ above)."
  exit 1
fi
