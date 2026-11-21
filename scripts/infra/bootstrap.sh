#!/usr/bin/env bash
# One command to bootstrap your own FoodSavr instance on Firebase (free web).
#
#   [MANIFEST=deploy/instance.yaml] [ENV=production] scripts/infra/bootstrap.sh [plan]
#
# Start from deploy/examples/firebase-free-web.yaml. Checks prerequisites,
# lists the steps only a human can do, validates the manifest, then runs
# scripts/infra/apply.sh. See specs/source-of-truth/deployment-levels.md.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
export MANIFEST="${MANIFEST:-$root/deploy/instance.yaml}"
export ENV="${ENV:-production}"

missing=0
need() {
  if command -v "$1" >/dev/null; then echo "  ok      $1"; else echo "  MISSING $1 ($2)"; missing=1; fi
}
echo "Prerequisites:"
need gcloud "https://cloud.google.com/sdk/docs/install"
need terraform "https://developer.hashicorp.com/terraform/install"
need dart "https://dart.dev/get-dart (bundled with Flutter)"
need python3 "https://www.python.org/downloads/ (bootstrap helpers)"
need npx "Node.js; runs firebase-tools"
command -v gh >/dev/null && echo "  ok      gh" || echo "  skip    gh (optional: sets GitHub Actions variables)"
[ "$missing" = 0 ] || { echo "Install the missing tools and re-run."; exit 1; }

cat <<EOF

Human-only steps (once per environment):
  1. Create a Firebase project: https://console.firebase.google.com
  2. Register a web app (Project settings -> Your apps -> Web) and enable
     Authentication (Email/Password) and Firestore.
  3. Put the project id, web app id and your GitHub owner/repo into
     $MANIFEST (template: deploy/examples/firebase-free-web.yaml).
  4. Log in: gcloud auth login && npx -y firebase-tools@15 login
     (and gh auth login to publish Actions variables).

EOF
read -r -p "Done? Validate and apply environment '$ENV' now [y/N] " ok
[ "$ok" = y ] || [ "$ok" = Y ] || exit 0

exec "$root/scripts/infra/apply.sh" "$@"
