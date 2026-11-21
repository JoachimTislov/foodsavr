---
name: flutter-standards
description: FoodSavr Dart/Flutter coding standards. Use before writing, refactoring, testing, or reviewing code under `lib/`, `test/`, `integration_test/`, or `packages/`, and when scaffolding a feature.
metadata:
  audience: agent
  paths: "lib/**,test/**,integration_test/**,packages/**"
---

# FoodSavr Flutter standards

The single source of truth for how FoodSavr code is written. `code-review` applies it on the Standards axis. Where it conflicts with [architecture.md](../../../specs/source-of-truth/architecture.md), the spec wins and the conflict is a sync finding.

Stack: Dart, Flutter (SDK >=3.32.0), Firebase Auth/Firestore, GetIt + `injectable`, `watch_it`, `logger`, `easy_localization`. Library deep-dives: `get-it-expert`, `watch-it-expert`; translations: `localization`.

## Layers

| Layer | Location | Holds |
|---|---|---|
| UI | `lib/views/`, `lib/widgets/` | Screens and reusable widgets; consume controllers and services only |
| Controller | `lib/controllers/` | `watch_it`-reactive view state |
| Service | `lib/services/`, `lib/features/*/services/` | Business logic, validation, orchestration |
| Data | `lib/interfaces/` (`i_*.dart`), `lib/repositories/` | Repository contracts and Firestore implementations |
| Domain | `lib/models/` | Plain data classes with `toJson`/`fromJson` |
| Shared core | `packages/foodsavr_core/` | Pure Dart; no Flutter or Firebase imports |

A new feature follows that order: model → interface → repository → service (constructor-injected interface) → `@injectable` registration → controller/view. Run `dart run build_runner build --delete-conflicting-outputs` after DI changes.

## Rules

- **Business logic lives in models, services, or controllers.** Widget `build` methods and view helpers hold markup only.
- **One widget per file.** Extract widgets as classes, never private `_buildX()` builders; centralize duplicated markup and logic in `lib/widgets/common/`.
- **Inject, never instantiate.** Constructor injection with `@injectable`; depend on `i_*` interfaces; call `getIt<T>()` only at the top of a view or in `main.dart`.
- **Firestore transactions return data.** Update application state after the transaction completes, never inside it.
- **Lightweight forms are bottom sheets.** Simple create/edit forms use `showModalBottomSheet` behind a static `show()`; full routes are for complex views.
- **Material 3 through the theme.** Colors from `ColorScheme.fromSeed`; component styles and typography in the central `ThemeData` (`lib/utils/app_theme.dart`, `lib/constants/material3_config.dart`); light, dark, and system modes.
- **No hard-coded values.** Constants in `lib/constants/`; user-facing strings through `easy_localization`.
- **Errors** are logged with `logger` and surfaced with an informative snackbar.
- **Encapsulation**: keep markup in the file that uses it until a second user exists; extract only verified duplication.
- **Style**: Effective Dart; `snake_case` files, `PascalCase` types, `camelCase` members, `_private`; `const` constructors and immutable widgets where possible; flat control flow (records, pattern matching, collection `if`/spread) over deep nesting.
- **Tooling** for the app is Dart in `scripts/`; agent and CI tooling under `scripts/agents/`, `scripts/github/`, and `scripts/secrets/` is Python.
- **Output**: comments and console output minimal and professional, no emojis.

## Tests

- Unit tests for models, services, and controllers; widget tests for reusable components (`flutter_test`); integration tests for end-to-end flows (`integration_test`) against the Firebase emulators.
- Prefer fakes and stubs; use `mocktail`/`mockito` only for complex external dependencies.
- Test-first work follows `tdd`.
- `make check` (analyze, test, locale-check, fix, format) is green before every commit. `make rules-test` covers Firestore rules.
