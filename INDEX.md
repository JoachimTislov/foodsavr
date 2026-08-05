# FoodSavr Codebase Index

This document maps the core files and folders of the codebase. Instead of guessing where to look, **always consult this index first** to understand the directory structure and to figure out what context each file provides.

## Layers Summary
- **UI (`views/`, `widgets/`)**: Screens and reusable components; inject services via `getIt<Service>()`.
- **Service (`services/`)**: Business logic, validation, orchestration; depends on repository **interfaces**.
- **Data (`interfaces/`, `repositories/`)**: Base contracts (`i_repository`, `i_service`) and feature contracts.
- **Domain (`models/`)**: Plain data classes with `toJson`/`fromJson` and computed properties.

## Core Entities & Structure

| Feature | Model | Interface | Implementation |
| :--- | :--- | :--- | :--- |
| Auth | N/A | `i_auth_service` | `auth_service` |
| Product | `product_model` | `i_product_repository` | `product_repository` |
| Collection | `collection_model` | `i_collection_repository` | `collection_repository` |

**Firestore Collections**: `products`, `collections`.
**Future Specs**: See `doc/implementation/` for users, shopping lists, recipes, meals, and groups.

## Directory Tree

```text
/
├── lib/                      # Application Source Code
│   ├── constants/            # Configuration, layout tokens, enums
│   ├── di/                   # Dependency injection third-party modules
│   ├── interfaces/           # Base contracts and APIs
│   ├── mock_data/            # Static instances of models for testing
│   ├── models/               # Domain data structures
│   ├── repositories/         # Data layer implementations (Firestore)
│   ├── services/             # Business logic layer
│   ├── utils/                # Utility classes, helpers, theme config
│   ├── views/                # Full-screen routed widgets
│   ├── widgets/              # Reusable UI components
│   ├── injection.dart        # GetIt configuration script
│   ├── main.dart             # Application entry point
│   ├── router.dart           # GoRouter definitions
│   └── service_locator.dart  # Dependency injection registry
├── test/                     # Unit and Widget Tests
│   ├── models/               # Domain model unit tests
│   ├── services/             # Business logic unit tests
│   ├── tool/                 # Tooling script tests
│   ├── utils/                # Utility unit tests
│   └── views/                # Widget tests for UI screens
└── integration_test/         # End-to-End Tests running on emulators
```

## Context Guide

Read the specific files and folders below to gather the appropriate context for your task.

### App Configuration & State
* **`lib/main.dart`**: Read this for application initialization, global error handling, and provider setups.
* **`lib/router.dart`**: Read this for GoRouter route definitions, path parameters, and authentication redirects.
* **`lib/service_locator.dart`**: Read this to understand how services, repositories, and third-party classes are injected.

### Data & Domain Rules
* **`lib/models/`**: Read these files to understand data structures (`product_model.dart`, `collection_model.dart`), their JSON serialization, and computed domain properties.
* **`lib/interfaces/`**: Read these abstract classes for the API definitions of repositories and services (e.g., `i_product_repository.dart`).
* **`lib/repositories/`**: Read these for the Firestore database interactions, document mapping, and query logic.

### Business Logic
* **`lib/services/`**: Read these for the core business logic, validation, domain rules, and orchestrations (e.g., `auth_service.dart`, `product_service.dart`, `barcode_scanner_service.dart`).
* **`test/services/`**: Read the corresponding test files to understand the expected behavior and edge cases of the business logic.

### User Interface (UI)
* **`lib/views/`**: Read these to understand full-screen layout, high-level screen interactions, and page structure.
* **`lib/widgets/`**: Read these files (organized by feature like `auth/`, `product/`) to understand specific, reusable UI components, local state, and design token usage.
* **`lib/utils/app_theme.dart`**: Read this for application-wide theme, colors, typography, and visual rules.
* **`lib/constants/`**: Read these for predefined categories, spacing tokens, and shared constants.

### Testing & Validation
* **`test/views/`**: Read these widget tests to understand how UI interactions are verified.
* **`integration_test/`**: Read E2E tests (`auth_test.dart`) to understand full user-journey flows and emulator interactions.

## Implementation Pattern (New Features)

When adding new features, follow this file creation and implementation sequence:

1. **Model**: `lib/models/` (JSON logic + computed properties).
2. **Interface**: `lib/interfaces/i_your_repository.dart`.
3. **Repository**: `lib/repositories/your_repository.dart` (Firestore impl).
4. **Service**: `lib/services/your_service.dart` (DI via constructor).
5. **DI**: Register the service/repository in `lib/service_locator.dart`.
6. **UI**: `lib/views/` & `lib/widgets/` (inject service via `getIt`).
7. **Test**: Create corresponding tests in `test/` using Firebase emulators.
