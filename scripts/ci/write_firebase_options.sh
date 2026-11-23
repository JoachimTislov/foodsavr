#!/usr/bin/env bash
set -euo pipefail

output='lib/firebase_options.dart'
if [[ -n "${FIREBASE_OPTIONS_B64:-}" ]]; then
  temp_dir=$(mktemp -d lib/.firebase-options.XXXXXX)
  candidate="$temp_dir/firebase_options.dart"
  trap 'if [[ -f "$candidate" ]]; then unlink "$candidate"; fi; rmdir "$temp_dir"' EXIT
  if printf '%s' "$FIREBASE_OPTIONS_B64" | base64 --decode > "$candidate" 2>/dev/null &&
      grep -q 'class DefaultFirebaseOptions' "$candidate" &&
      dart format "$candidate" >/dev/null 2>&1; then
    mv "$candidate" "$output"
    exit 0
  fi
fi

if [[ "${1:-}" == --require-real ]]; then
  echo '::error::FIREBASE_OPTIONS_B64 must contain valid Firebase options for remote Android delivery.' >&2
  exit 1
fi

if [[ ! -s "$output" ]]; then
  cat > "$output" <<'DART'
// Compile-only placeholder for CI without usable Firebase options.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform =>
      throw UnsupportedError('FirebaseOptions are not configured for this CI run');
}
DART
  dart format "$output" >/dev/null
fi
message='Usable FIREBASE_OPTIONS_B64 is unavailable. Kept existing options or used a compile-only placeholder.'
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf '%s\n' "$message" >> "$GITHUB_STEP_SUMMARY"
else
  printf '%s\n' "$message"
fi
