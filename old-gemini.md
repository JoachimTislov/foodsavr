## 0. SDK & Dependency Constraints

> ⚠️ **Always verify API availability against the minimum supported versions below before using any Flutter/Dart API.**
> Using APIs introduced after these minimums will compile locally but break on older runtimes.

| Constraint | Value | Source |
| :--- | :--- | :--- |
| **Dart SDK** | `^3.10.7` (min `3.10.7`) | `pubspec.yaml › environment.sdk` |
| **Flutter** | `>=3.32.0` | `pubspec.yaml › environment.flutter` |

### Known API availability relative to Flutter `3.32.0`

| API | Available since | Notes |
| :--- | :--- | :--- |
| `Color.withValues(...)` | Flutter 3.27.0 ✅ | Replacement for `withOpacity` |
| `WidgetStateProperty<T>` | Flutter 3.22.0 ✅ | Replacement for `MaterialStateProperty` |
| `CardThemeData` | Flutter 3.32.0 ✅ | Required — `ThemeData.cardTheme` is now typed `CardThemeData?` |
| `DialogThemeData` | Flutter 3.32.0 ✅ | Required — `ThemeData.dialogTheme` is now typed `DialogThemeData?` |
| `TabBarThemeData` | Flutter 3.32.0 ✅ | Required — `ThemeData.tabBarTheme` is now typed `TabBarThemeData?` |


