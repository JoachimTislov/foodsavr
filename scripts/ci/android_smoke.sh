#!/usr/bin/env bash
# CI emulator smoke runner. Preserve visual evidence even when startup fails.
set -euo pipefail

# An emulator that drops offline makes adb print "waiting for device" and block
# until the job's 60-minute timeout; bound every adb call so the run fails fast.
# timeout(1) needs an executable path, not the `command` builtin.
adb_bin=$(type -P adb)
adb() { timeout "${ADB_TIMEOUT_SECONDS:-120}" "$adb_bin" "$@"; }

mkdir -p artifacts/android-visuals
recording_pid=''
collect() {
  status=$?
  trap - EXIT
  set +e
  adb exec-out screencap -p > artifacts/android-visuals/startup.png || status=1
  adb shell pkill -INT screenrecord
  if [ -n "$recording_pid" ]; then wait "$recording_pid"; fi
  adb pull /sdcard/foodsavr-startup.mp4 artifacts/android-visuals/startup.mp4 || status=1
  adb logcat -d > artifacts/android-visuals/logcat.txt
  test -s artifacts/android-visuals/startup.png || status=1
  test -s artifacts/android-visuals/startup.mp4 || status=1
  exit "$status"
}
trap collect EXIT

adb install -r build/app/outputs/flutter-apk/app-development-debug.apk
adb logcat -c
adb shell screenrecord --time-limit 30 /sdcard/foodsavr-startup.mp4 &
recording_pid=$!
adb shell am start -W -n com.foodsavr.app.development/com.foodsavr.app.MainActivity
sleep 15
app_pid=$(adb shell pidof com.foodsavr.app.development | tr -d '\r\n')
test -n "$app_pid"
adb shell dumpsys activity activities | grep -E 'ResumedActivity.*com.foodsavr.app.development'
adb logcat -d --pid="$app_pid" > artifacts/android-visuals/app-logcat.txt
if grep -qiE 'Unhandled Exception|FATAL EXCEPTION' artifacts/android-visuals/app-logcat.txt; then
  echo '::error::Android app failed during startup'
  exit 1
fi
