#!/usr/bin/env bash
# Run by android-emulator-runner, which executes each script line separately.
set -e
if [ "$RUN_ANDROID_SMOKE" = "true" ]; then
  adb install -r build/app/outputs/flutter-apk/app-development-debug.apk
  adb shell am start -W -n com.foodsavr.app.development/com.foodsavr.app.MainActivity
  adb wait-for-device
  for i in $(seq 1 30); do adb shell pidof com.foodsavr.app.development > /dev/null && break; sleep 1; done
  adb shell pidof com.foodsavr.app.development
  for i in $(seq 1 30); do adb shell "dumpsys activity activities 2>/dev/null | grep -q 'ResumedActivity.*com.foodsavr.app.development/com.foodsavr.app.MainActivity'" && break; sleep 2; done; adb shell "dumpsys activity activities 2>/dev/null | grep -q 'ResumedActivity.*com.foodsavr.app.development/com.foodsavr.app.MainActivity'"
  for i in $(seq 1 30); do adb shell "dumpsys window 2>/dev/null | grep -Eq '(mCurrentFocus|mFocusedApp).*com.foodsavr.app.development'" && break; sleep 2; done; adb shell "dumpsys window 2>/dev/null | grep -Eq '(mCurrentFocus|mFocusedApp).*com.foodsavr.app.development'"
  sleep 5
  adb shell "dumpsys window windows 2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp'" || true
  adb logcat -d -t 200 | grep -iE 'flutter|foodsavr' | tail -30 || true
  APP_PID=$(adb shell pidof com.foodsavr.app.development | tr -d '\r\n')
  adb logcat -d --pid="$APP_PID" -s AndroidRuntime:E | (! grep -q 'FATAL EXCEPTION')
  adb logcat -d --pid="$APP_PID" | grep -v 'FlutterJNI\|chromium\|eglCodecCommon' | (! grep -qi 'unhandled exception\|FATAL EXCEPTION')
fi
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
flutter test integration_test --flavor development --no-pub
