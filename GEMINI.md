# FoodSavr - Guidelines

Project architecture, principles, and rules for `foodsavr` (Flutter SDK ^3.10.7).

## 1. Tech & Architecture
- **Tech Stack**: Dart, Firebase (Auth/Firestore), GetIt (DI), logger, easy_localization.
- **Pattern**: 4-tier Layered Architecture (UI → Services → Repositories → Models).
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

## Commands
- make push: Push to remote repository
- `make deps`: Fetch dependencies.
- `make check`: Run full suite (analyze, format, test). **Required before commit**.

## 4. **Workflow**:
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

## Implementation Pattern (New Features)
1. **Model**: `@models/` (JSON logic + computed properties).
2. **Interface**: `@interfaces/i_your_repository.dart`.
3. **Repository**: `@repositories/your_repository.dart` (Firestore impl).
4. **Service**: `@services/your_service.dart` (DI via constructor).
5. **DI**: Register in `@service_locator.dart`.
6. **UI**: `@views/` & `@widgets/` (inject service via `getIt`).
7. **Test**: Use Firebase emulators (`@test/`).
