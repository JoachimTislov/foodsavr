# Issue: Gradle build failed to produce an .apk file

## Description

When running `flutter build apk`, `flutter build appbundle`, or `flutter run` on Android in this project without specifying a flavor, the build might finish but immediately throw this error:

> "Gradle build failed to produce an .apk file. It's likely that this file was generated under /path/to/project/build, but the tool couldn't find it."

You will notice that the Dart-level exception (`if (appFlavor == null) throw Exception(...)` in `main.dart`) is **not** thrown in the console when this happens.

## Root Cause: The Two Layers of Failure

This project requires **product flavors** (`development` and `production`) to isolate environments (like Firebase). If you forget to pass the `--flavor` flag, the app fails in one of two ways, depending on the platform:

### 1. The Gradle Layer (Android)
On Android, the build crashes **before your code ever reaches the phone or emulator.** 
When you run `flutter run` without a flavor, Gradle attempts to build all available flavors (e.g., `app-development-debug.apk` and `app-production-debug.apk`). However, the Flutter CLI expects to find a single, generic `app-debug.apk` output file to install on your device. When it cannot find it, it assumes the build failed, halts the deployment, and throws the generic error above. 

Because the app is never installed or launched, the `main()` function in `main.dart` is never executed, which is why the Dart exception isn't thrown on Android.

### 2. The Dart Layer (Cross-Platform Fallback)
As a second line of defense, we added a safeguard in `main.dart`:
```dart
if (appFlavor == null && !kIsWeb) {
  throw Exception('No app flavor provided...');
}
```
Why is this necessary if Android crashes anyway?
* **Other Platforms:** iOS and macOS build systems often *don't* crash when a flavor is missing. They will successfully build, launch the app, and *then* the Dart exception will correctly catch the missing configuration.
* **Cached APKs:** Sometimes Android deployment gets confused and accidentally installs an old, previously successful APK. If an old APK launches without the right environment variables, the Dart exception ensures the app safely halts instead of interacting with the wrong backend database.

## Solution

You must explicitly tell Flutter which flavor you want to build or run. 

**Recommended:**
Use the predefined Make targets, which automatically handle flavors and `.env` flags:
```bash
make run-dev     # Runs the development flavor with local emulators
make run-prod    # Runs the production flavor
```

**Manual CLI usage:**
If you must use the Flutter CLI directly, always append the `--flavor` flag:
```bash
flutter run --flavor development
flutter build apk --flavor production
```
