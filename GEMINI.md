# FoodSavr - Guidelines

Project architecture, principles, and rules for `foodsavr` (Flutter SDK ^3.10.7).

## 1. Tech & Architecture
- **Tech Stack**: Dart, Firebase (Auth/Firestore), GetIt (DI), logger, easy_localization.
- **Pattern**: 3-tier Layered Architecture (UI → Services → Repositories → Models).
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

## 3. Standards & Workflow
- **Widget Rules**: **One widget per file**; no private builders (e.g., `_buildX()`) in views; keep view files < 200 lines.
- **Strict Separation**: Business logic **MUST** reside in models or services. **ZERO** business logic in widget build methods or private view helpers.
- **Development Workflow**:
  - run "rg -g" instead of "rg --g". It is not supported (ripgrep --help gives you --glob/-g, not --g).
  - make dev-chrome: Run in Chrome.
  - `make deps`: Fetch dependencies.
  - `make check`: Run full suite (analyze, format, test). **Required before commit**.
  - `make start-firebase-emulators`: Start local backend (Auth/Firestore).
  - `make kill-firebase-emulators`: Stop backend.
  - **Task Completion Rule**: After each completed task (or small batch of closely related tasks), commit and push immediately.
  - **Commit Message Rule**: Use clear, descriptive commit messages; prefer Conventional Commits style (e.g., `fix(router): handle auth redirect after login`).
  - **Iteration Rule**: Work one task/thread at a time: retrieve one item, implement, validate, commit, then continue.
  - **PR Script Rule**: Prefer GitHub PR helper scripts that list/resolve exactly one thread per run to keep context narrow and avoid accidental bulk actions.
- **Style**: `snake_case` (files), `camelCase` (members), `_private`. Follow [Effective Dart](https://dart.dev/effective-dart/design).

### Implementation Pattern (New Features)
1. **Model**: `@models/` (JSON logic + computed properties).
2. **Interface**: `@interfaces/i_your_repository.dart`.
3. **Repository**: `@repositories/your_repository.dart` (Firestore impl).
4. **Service**: `@services/your_service.dart` (DI via constructor).
5. **DI**: Register in `@service_locator.dart`.
6. **UI**: `@views/` & `@widgets/` (inject service via `getIt`).
7. **Test**: Use Firebase emulators (`@test/`).
