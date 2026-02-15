# FoodSavr - Project Guidelines

This document reflects the current architecture and outlines the code structure, architectural principles, and general rules for the `foodsavr` Flutter project. Adhering to these guidelines ensures consistency, maintainability, and scalability of the codebase.

## 1. Project Overview

FoodSavr is a Flutter application designed to help people reduce food waste by tracking product expiration dates, managing inventory, and cross-referencing recipes.

## 2. Tech Stack

*   **Framework**: Flutter (SDK ^3.10.7)
*   **Language**: Dart
*   **State Management**: Basic StatefulWidget (planned: Provider/Riverpod for complex features)
*   **Backend**: Firebase Auth, Firestore
*   **Dependency Injection**: GetIt (service locator pattern)
*   **Logging**: `logger` package
*   **Localization**: `easy_localization`
*   **Environment Config**: `flutter_dotenv`

## 3. Architecture

The codebase follows a **3-tier layered architecture** with **dependency injection** and **Firebase emulators for development**.

### Core Principles

1. **Repository Pattern with Interfaces**: All data access through abstract interfaces (`lib/interfaces/`)
2. **Dependency Injection**: GetIt service locator - never instantiate dependencies directly
3. **Separation of Concerns**: UI → Services → Repositories → Models
4. **Emulator-Driven Development**: Uses Firebase emulators in development, production Firebase in production
5. **Zero hard-coded values**: Use constants or configuration files

### Layers

#### Presentation Layer (`views/` and `widgets/`)
- **Views**: Full-screen components (e.g., `auth_view.dart`, `product_list_view.dart`)
- **Widgets**: Reusable UI components organized by feature (e.g., `widgets/auth/`, `widgets/product/`)
- **Responsibilities**: Display data, handle user input, delegate to services
- **Dependency Access**: Inject via `getIt<Service>()` in `initState()`

#### Application Layer (`services/`)
- Orchestrates use cases
- Contains validation and business rules
- Logging and error handling
- Depends on repository **interfaces**, not implementations

**Services:**
- `AuthService` - Authentication orchestration + validation
- `ProductService` - Product operations + logging
- `SeedingService` - Initial data seeding

#### Data Access Layer (`repositories/` and `interfaces/`)

**Interfaces** (`lib/interfaces/`):
- `i_auth_repository.dart` - Authentication contract
- `i_user_repository.dart` - User data contract
- `i_product_repository.dart` - Product data contract
- `i_collection_repository.dart` - Collection data contract

**Implementations** (`lib/repositories/`):
- **Firestore** (all environments):
  - `firestore_user_repository.dart` (FirestoreUserRepository)
  - `firestore_product_repository.dart` (FirestoreProductRepository)
  - `firestore_collection_repository.dart` (FirestoreCollectionRepository)
  - Connects to emulators in development (`ENVIRONMENT=development`)
  - Connects to production Firebase in production (`ENVIRONMENT=production`)
- **Firebase Auth**:
  - `auth_repository.dart` (FirebaseAuthRepository)
  - Connects to Auth emulator (port 9099) in development

#### Domain Models (`models/`)
- Plain data classes with serialization
- `toJson()` / `fromJson()` methods for Firestore
- No dependencies on other layers

**Models:**
- `user.dart` - User entity
- `product_model.dart` - Product entity
- `collection_model.dart` - Collection entity

## 4. Directory Structure

```
lib/
├── main.dart                       # App entry point, DI initialization
├── service_locator.dart            # GetIt configuration with emulator support
├── constants/                      # Application-wide constants
│   └── environment_config.dart     # Environment variables + isProduction flag
├── interfaces/                     # Repository contracts
│   ├── i_auth_repository.dart
│   ├── i_user_repository.dart
│   ├── i_product_repository.dart
│   └── i_collection_repository.dart
├── models/                         # Domain models with serialization
│   ├── user.dart
│   ├── product_model.dart
│   └── collection_model.dart
├── repositories/                   # Data access implementations
│   ├── auth_repository.dart        # Firebase Auth
│   └── firestore_*_repository.dart # Firestore (all environments)
├── services/                       # Business logic
│   ├── auth_service.dart
│   ├── product_service.dart
│   └── seeding_service.dart
├── views/                          # Full-screen UI
│   ├── auth_view.dart
│   ├── product_list_view.dart
│   └── main_view.dart
├── widgets/                        # Reusable components
│   ├── auth/
│   └── product/
├── utils/                          # Helper utilities
│   └── environment_config.dart
└── features/                       # Reserved for future feature modules
```

## 7. Coding Standards

- File names: `lowercase_with_underscores.dart`
- Classes, variables, functions: `camelCase`
- Private members: Prefix with underscore `_privateMember`
- Indentation: 2 spaces
- Linting: `flutter_lints` (configured in `analysis_options.yaml`)
- Follow [Effective Dart](https://dart.dev/effective-dart/design) guidelines
- [coding-standards](./coding-standards.md) for detailed rules

## 8. Testing

*   Unit and widget tests are located in the `test/` directory
*   Tests use Firebase emulators for integration testing
*   Run tests using `flutter test`
*   For CI, start emulators before running tests

## Linting and testing

```bash
make analyze # Check for issues
make test    # Run tests
make fmt     # Format code
```

## 10. Adding New Features

Follow this pattern when adding features:

1. **Define the domain model** in `models/` with `toJson()`/`fromJson()`
2. **Create repository interface** in `interfaces/i_your_repository.dart`
3. **Implement Firestore repository** in `repositories/firestore_your_repository.dart`
4. **Create service** in `services/your_service.dart` for business logic
5. **Register in DI** container (`service_locator.dart`)
6. **Build UI** in `views/` and `widgets/`, injecting dependencies via GetIt
7. **Test with emulators** before deploying to production

## Firestore Collections

- `users` - User profiles
- `products` - Food products
- `collections` - Product collections/baskets

## 12. Git Workflow

*   Commit messages should be clear, concise, and descriptive
*   Avoid committing generated files (handled by `.gitignore`)
*   Run `flutter analyze` before committing

---
