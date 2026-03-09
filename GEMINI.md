# FoodSavr - Guidelines

Project architecture, principles, and rules for `foodsavr` (Flutter SDK >=3.32.0).

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

### Rule
When reviewing or writing code, **check [pub.dev](https://pub.dev) or the [Flutter breaking-changes doc](https://docs.flutter.dev/release/breaking-changes) if unsure** whether an API exists at the minimum Flutter version. If a newer API is used, either raise the minimum version in `pubspec.yaml` or use the older equivalent.


- **Tech Stack**: Dart, Firebase (Auth/Firestore), GetIt (DI), logger, easy_localization.
- **Pattern**: 3-tier Layered Architecture
- **Core Principles**: Interface-based data access, DI for all dependencies, Emulator-driven dev.

### Layers Summary
- **UI (`views/`, `widgets/`)**: Screens and reusable components; inject services via `getIt<Service>()`.
- **Service (`services/`)**: Business logic, validation, orchestration; depends on repository **interfaces**.
- **Data (`interfaces/`, `repositories/`)**: Base contracts (`i_repository`, `i_service`) and feature contracts.
- **Domain (`models/`)**: Plain data classes with `toJson`/`fromJson` and computed properties.

## 2. Core Entities & Structure

| Feature | Model | Interface | Implementation |
| :--- | :--- | :--- | :--- |
| Auth | N/A | `i_auth_service` | `auth_service` |
| Product | `product_model` | `i_product_repository` | `product_repository` |
| Collection | `collection_model` | `i_collection_repository` | `collection_repository` |

**Firestore Collections**: `products`, `collections`.
**Future Specs**: See `@docs/implementation/` for users, shopping lists, recipes, meals, and groups.

## 3. Standards
- **Widget Rules**: **One widget per file**; no private builders (e.g., `_buildX()`) in views; keep view files < 200 lines.
- **Strict Separation**: Business logic **MUST** reside in models or services. **ZERO** business logic in widget build methods or private view helpers.
- **Lightweight Forms as Bottom Sheets**: Simple create/edit forms (e.g., collection form, product picker) should use `showModalBottomSheet` with a static `show()` method instead of full-screen route navigation. Reserve full routes for complex views.
- **No Python Scripts**: Use Dart scripts in `tool/` for any project tooling. Do not use Python.

## Commands
- make push: Push to remote repository
- `make deps`: Fetch dependencies.
- `make check`: Run full suite (analyze, format, test). **Required before commit**.

## 4. **Workflow**:
- **Meta-Task Branch Rule**: Reserve the main working branch for "meta" tasks (agents, documentation, research, system-level updates). All source code modifications MUST be delegated to background agents in separate Git worktrees.
- **Headless Task Rule**: All implementation, bug fixes, and source code changes MUST be executed using `gemini --task <task_description>` (headless mode). The interactive session MUST NOT directly perform source code changes.
- **No Orchestration Make Targets**: Do NOT include `make` targets for task orchestration or PR management (e.g., `make seed`, `make pr-comments-*`). Use the CLI's native agent capabilities instead.
- **Multi-Agent Worktree Rule**: Spin up background agents in separate Git worktrees to isolate source code tasks (PRs, issues). This allows the main process to remain dedicated to orchestration and meta-tasks.
- **Task Ordering Rule**: Prioritize tasks in the following order: (1) handle existing PRs, (2) handle open issues, (3) create new issues systematically from the `TODO.md` / TODO folder backlog.
- **Worktree Sync Rule**: Always sync every new worktree with the `main` branch before commencing work to ensure the agent operates on the latest context.
- **TODO Prioritization Rule**: TODOs from local backlog files should only be tackled when there are no open issues and no open PRs available.
- **Task Completion Rule**: After each completed task (or tight related batch), commit and push immediately.
- **Commit Message Rule**: Use clear descriptive messages; prefer Conventional Commits (e.g., `fix(router): handle auth redirect`).
- **Execution Loop Rule**: Gather context (code/tests/PR comments/docs/rules/skills), check for missing context, implement minimal fix, run `make check`, add/update tests, run `make check` until green, run `make push`; if `make push` fails, fix and repeat from `make check`.
- **Introspection Rule**: Re-evaluate context after each major step and keep only task-relevant information.
- **PR Script Rule**: Use one-thread-per-run PR scripts to keep context narrow and avoid bulk actions.
- **Future Improvement Logging Rule**: Log follow-ups in `log/review-thread-followups.log` only when improvement is still needed (id, remaining gap, next action).
- **Implementation Rationale Rule**: Record a concise reason (1-2 lines) for why the chosen approach was used.
- **Quality Risk Logging Rule**: If quality may be weak at current stage, log task/risk/impact/follow-up in `log/implementation-risks.log`.
- **Resolved Comment Cleanup Rule**: Remove stale comment references once high-quality, Effective Dart-aligned, non-fragile solutions are fully implemented.
- **Style**: `snake_case` (files), `camelCase` (members), `_private`. Follow [Effective Dart](https://dart.dev/effective-dart/design).

## 5. Environment Configuration
- **.env Support**: The project uses a `.env` file in the root for environment variables.
- **Flutter**: Loaded via `String.fromEnvironment` (passed by `Makefile` using `--dart-define-from-file`).
- **Android**: Loaded in `android/app/build.gradle.kts`. Variables are available as `manifestPlaceholders` and `resValue` (e.g., `@string/EMULATOR_HOST`).
- **Host IP**: For local development (Firebase emulators), set `EMULATOR_HOST` in `.env`.
- **Android Sync**: The `network_security_config.xml` includes common development IPs. If you use a custom IP not in the XML, you must add it there to allow cleartext traffic.
- **Emulator UI**: Access the Firebase Emulator UI at `http://localhost:8081`.

## Implementation Pattern (New Features)
1. **Model**: `@models/` (JSON logic + computed properties).
2. **Interface**: `@interfaces/i_your_repository.dart`.
3. **Repository**: `@repositories/your_repository.dart` (Firestore impl).
4. **Service**: `@services/your_service.dart` (DI via constructor).
5. **DI**: Register in `@service_locator.dart`.
6. **UI**: `@views/` & `@widgets/` (inject service via `getIt`).
7. **Test**: Use Firebase emulators (`@test/`).
