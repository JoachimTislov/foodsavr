#!/usr/bin/env bash
# Manual bypass for the web-monitor operation (.github/actions/web-probe): probe a live URL with
# the same scripts the workflow runs, then route a failure through fault intake
# and verify/close resolved healing issues. Uses your own `gh` login.
#
#   scripts/monitoring/monitor_web.sh URL [--apply]
#
# Dry run (no issues opened or closed) unless --apply. Needs Node and, once,
# `npm --prefix test/e2e ci && npx --prefix test/e2e playwright install chromium`
# (done here when the dependencies are missing).
set -euo pipefail

url="${1:-${MONITOR_TARGET_URL:-}}"
[ -n "$url" ] || { echo "usage: $0 URL [--apply]  (or set MONITOR_TARGET_URL)" >&2; exit 2; }
apply=false
[ "${2:-}" = "--apply" ] && apply=true

if [ ! -d test/e2e/node_modules ]; then
  npm --prefix test/e2e ci
  npx --prefix test/e2e playwright install chromium
fi

report="$(mktemp)"
trap 'rm -f "$report"' EXIT
sha="${RELEASE_SHA:-}"
node scripts/monitoring/probe_web.mjs --url "$url" --release-sha "$sha" \
  --deployment-level "firebase-${FIREBASE_PLAN:-spark}" --environment "${MONITOR_ENVIRONMENT:-production}" \
  --output "$report" --no-fail
ok=$(python3 -c 'import json,sys; print("true" if json.load(open(sys.argv[1])).get("ok") else "false")' "$report")
cat "$report"

dry=()
$apply || dry=(--dry-run)
verify=(--probe-file "$report" --target-url "$url" --deployed-sha "$sha")
if [ "$ok" != true ]; then
  branch=$(git symbolic-ref --quiet refs/remotes/origin/HEAD || true)
  branch="${branch#refs/remotes/origin/}"
  intake=(--input "$report" --ref "${branch:-develop}")
  [ "${AUTO_HEAL_ENABLED:-}" = true ] && $apply && intake+=(--dispatch)
  python3 scripts/monitoring/fault_intake.py "${intake[@]}" "${dry[@]}"
fi
python3 scripts/monitoring/verify_and_close.py "${verify[@]}" "${dry[@]}"
[ "$ok" = true ] || { echo "Web probe failed on $url" >&2; exit 1; }
