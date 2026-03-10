old stuff from gemini.md

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


## 5. Environment Configuration
- **Flutter**: Loaded via `String.fromEnvironment` (passed by `Makefile` using `--dart-define-from-file`).
- **Android**: Loaded in `android/app/build.gradle.kts`. Variables are available as `manifestPlaceholders` and `resValue` (e.g., `@string/EMULATOR_HOST`).
- **Host IP**: For local development (Firebase emulators), set `EMULATOR_HOST` in `.env`.
- **Android Sync**: The `network_security_config.xml` includes common development IPs. If you use a custom IP not in the XML, you must add it there to allow cleartext traffic.
- **Emulator UI**: Access the Firebase Emulator UI at `http://localhost:8081`.

### Asynchronous Agents
- **Headless Task Rule**: All implementation, bug fixes, and source code changes MUST be executed using `gemini --prompt <task_description>` (headless mode). The interactive session MUST NOT directly perform source code changes.
- **Worktree Sync Rule**: Always sync every new worktree with the `main` branch before commencing work to ensure the agent operates on the latest context.
- **PR Script Rule**: Use one-thread-per-run PR scripts to keep context narrow and avoid bulk actions.
- **Asynchronous Execution Rule**: Use the `run_shell_command` tool with the `is_background: true` parameter to execute tasks asynchronously.
- **Multi-Agent Worktree Rule**: Spin up background agents in separate Git worktrees to isolate source code tasks (PRs, issues). This allows the main process to remain dedicated to orchestration and meta-tasks.


