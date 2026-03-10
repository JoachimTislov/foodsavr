# FoodSavr - Guidelines

Project architecture, principles, and rules for `foodsavr` (Flutter SDK >=3.32.0).

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
- **Meta-Task Branch Rule**: Reserve the main working branch (default folder) for "meta" tasks (agents, documentation, research, system-level updates). All source code modifications must be made in separate Git worktrees.
- **Task Ordering Rule**: Prioritize tasks in the following order: (1) handle existing PRs, (2) handle open issues, (3) create new issues systematically from the `TODO.md` / TODO folder backlog.
- **TODO Prioritization Rule**: TODOs from local backlog files should only be tackled when there are no open issues and no open PRs available.
- **Task Completion Rule**: After each completed task (or tight related batch), commit and push immediately.
- **Commit Message Rule**: Use clear descriptive messages; prefer Conventional Commits (e.g., `fix(router): handle auth redirect`).
- **Execution Loop Rule**: Gather context (code/tests/PR comments/docs/rules/skills), check for missing context, implement minimal fix, run `make check`, add/update tests, run `make check` until green, run `make push`; if `make push` fails, fix and repeat from `make check`.
- **Introspection Rule**: Re-evaluate context after each major step and keep only task-relevant information.
- **Future Improvement Logging Rule**: Log follow-ups in `log/review-thread-followups.log` only when improvement is still needed (id, remaining gap, next action).
- **Implementation Rationale Rule**: Record a concise reason (1-2 lines) for why the chosen approach was used.
- **Quality Risk Logging Rule**: If quality may be weak at current stage, log task/risk/impact/follow-up in `log/implementation-risks.log`.
- **Resolved Comment Cleanup Rule**: Remove stale comment references once high-quality, Effective Dart-aligned, non-fragile solutions are fully implemented.
- **Style**: `snake_case` (files), `camelCase` (members), `_private`. Follow [Effective Dart](https://dart.dev/effective-dart/design).

## Implementation Pattern (New Features)
1. **Model**: `@models/` (JSON logic + computed properties).
2. **Interface**: `@interfaces/i_your_repository.dart`.
3. **Repository**: `@repositories/your_repository.dart` (Firestore impl).
4. **Service**: `@services/your_service.dart` (DI via constructor).
5. **DI**: Register in `@service_locator.dart`.
6. **UI**: `@views/` & `@widgets/` (inject service via `getIt`).
7. **Test**: Use Firebase emulators (`@test/`).
