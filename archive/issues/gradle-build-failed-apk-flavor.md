# Issue: Gradle build failed to produce an .apk file

## Description

When running `flutter build apk` (or `flutter build appbundle`) in this project, the build might finish but immediately throw this error:

> "Gradle build failed to produce an .apk file. It's likely that this file was generated under /path/to/project/build, but the tool couldn't find it."

## Root Cause

This issue occurs because the project has Android **product flavors** configured (`development` and `production`), but you ran the build command without specifying which flavor to build. 

When you run `flutter build apk` without the `--flavor` flag, Gradle actually succeeds and builds an APK for *each* flavor (e.g., `app-development-release.apk` and `app-production-release.apk`). However, the Flutter CLI expects to find a single, generic `app-release.apk` output file. When it cannot find it, it assumes the build failed and throws the error.

## Solution

You must explicitly tell Flutter which flavor you want to build by using the `--flavor` flag. 

To build your **development** environment:
```bash
flutter build apk --flavor development
```

Or to build your **production** environment:
```bash
flutter build apk --flavor production
```

*(Note: The same rule applies to `flutter run` and other build commands like `flutter build appbundle`—you should always append `--flavor [name]` to your commands in this project.)*
