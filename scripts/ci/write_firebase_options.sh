#!/usr/bin/env bash
set -euo pipefail

output='lib/firebase_options.dart'
if [ -s "$output" ]; then
  exit 0
fi
echo "::error::$output is missing; restore the tracked defines template from git." >&2
exit 1
