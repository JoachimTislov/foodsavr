#!/usr/bin/env bash
set -euo pipefail

output='lib/firebase_options.dart'
if [ -z "${FIREBASE_OPTIONS_B64:-}" ]; then
  if [ -s "$output" ]; then
    echo "::warning::FIREBASE_OPTIONS_B64 is missing; preserving the existing Firebase options file."
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
      echo '⚠️ FIREBASE_OPTIONS_B64 missing; preserved the existing Firebase configuration.' >> "$GITHUB_STEP_SUMMARY"
    fi
    exit 0
  fi
  cat > "$output" <<'EOF'
// Placeholder used when CI does not provide Firebase credentials.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'FirebaseOptions are not configured for this CI run');
}
EOF
  echo '::warning::FIREBASE_OPTIONS_B64 is missing; using a compile-only Firebase placeholder.'
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo '⚠️ FIREBASE_OPTIONS_B64 missing; Firebase-dependent runtime checks may be unavailable.' >> "$GITHUB_STEP_SUMMARY"
  fi
  exit 0
fi

if ! printf '%s' "$FIREBASE_OPTIONS_B64" | base64 --decode > "$output" || [ ! -s "$output" ]; then
  echo '::error::FIREBASE_OPTIONS_B64 is present but is not valid non-empty base64.'
  exit 1
fi
