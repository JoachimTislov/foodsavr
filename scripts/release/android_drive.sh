#!/usr/bin/env bash
# Build the Android test APK and upload it to Google Drive.
#
# One implementation for .github/workflows/manual-tools.yml (android-drive-test) and the
# manual bypass `make android-apk LOCAL=1`, so the two cannot drift.
#
#   android_drive.sh build    derive native Android config, build the APK
#   android_drive.sh upload   upload it (GOOGLE_DRIVE_FOLDER_ID, GOOGLE_DRIVE_OAUTH_JSON)
#
# Locally existing android/.../google-services.json and assets/.env are kept
# when ANDROID_ENV_B64 is unset. Firebase client options come from
# FIREBASE_DEFINES or the local defines file (scripts/firebase_options.py).
set -euo pipefail

apk=build/app/outputs/flutter-apk/app-production-debug.apk

case "${1:-}" in
  build)
    bash scripts/ci/write_android_test_config.sh
    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter build apk --flavor production --debug "--dart-define-from-file=$(python3 scripts/firebase_options.py path)"
    ;;
  upload)
    : "${GOOGLE_DRIVE_FOLDER_ID:?Missing GOOGLE_DRIVE_FOLDER_ID}"
    : "${GOOGLE_DRIVE_OAUTH_JSON:?Missing GOOGLE_DRIVE_OAUTH_JSON}"
    python3 scripts/release/upload_drive.py "$apk"
    ;;
  *)
    echo "usage: $0 build|upload" >&2
    exit 2
    ;;
esac
