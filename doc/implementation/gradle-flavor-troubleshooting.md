# Gradle flavor troubleshooting

Running `flutter build apk`, `flutter build appbundle`, or `flutter run` on
Android without specifying a product flavor causes the build to fail before the
Dart entrypoint runs. This guide explains why the failure happens and how to
run or build FoodSavr with the required flavor.

## Symptom

When you omit `--flavor` on Android, the build finishes Gradle compilation and
immediately fails with the following message:

> "Gradle build failed to produce an .apk file. It's likely that this file was
> generated under /path/to/project/build, but the tool couldn't find it."

The Dart-level guard in `lib/main.dart` (`if (appFlavor == null && !kIsWeb)`)
does not run in this failure path because the app is never installed or
launched.

## Root cause

FoodSavr defines two Android product flavors (`development` and `production`)
to keep Firebase and environment configuration isolated. Omitting `--flavor`
triggers one of two safeguards depending on the target platform.

### Gradle layer (Android)

When you run a Flutter Android command without `--flavor`, Gradle builds
flavor-specific APK artifacts (such as `app-development-debug.apk` and
`app-production-debug.apk`). The Flutter CLI looks for a generic
`app-debug.apk` output, fails to find it, and halts deployment before `main()`
executes.

### Dart layer (cross-platform fallback)

`lib/main.dart` includes a runtime guard:

```dart
if (appFlavor == null && !kIsWeb) {
  throw Exception('No app flavor provided...');
}
```

This fallback covers two cases where Gradle does not block execution:

- **Non-Android platforms:** iOS and macOS builds can launch without a flavor
  and rely on the Dart check to surface the missing configuration.
- **Cached APKs:** If Android tooling launches a stale APK without the expected
  flavor configuration, the guard stops the app before it connects to the wrong
  backend.

## Solution

Always provide a flavor when running or building native targets.

Use the `Makefile` targets, which pass the required `--flavor` and environment
flags automatically:

```bash
make run-dev     # Runs the development flavor with local emulators
make run-prod    # Runs the production flavor
```

If you invoke the Flutter CLI directly, append `--flavor`:

```bash
flutter run --flavor development
flutter build apk --flavor production
```
