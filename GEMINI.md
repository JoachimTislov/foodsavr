# FoodSavr - Project Guidelines

This document outlines the code structure, architectural principles, and general rules for the `foodsavr` Flutter project. Adhering to these guidelines ensures consistency, maintainability, and scalability of the codebase.

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

The codebase follows a **3-tier layered architecture** with **dependency injection** and **environment-based configuration**.

### Core Principles

1. **Repository Pattern with Interfaces**: All data access through abstract interfaces (`lib/interfaces/`)
2. **Dependency Injection**: GetIt service locator - never instantiate dependencies directly
3. **Separation of Concerns**: UI → Services → Repositories → Models
4. **Environment-Aware**: Automatically switches between development (in-memory) and production (Firestore) implementations
5. **Zero hard-coded values**: Use constants or configuration files

### Layers

#### Presentation Layer (`views/` and `widgets/`)
- **Views**: Full-screen components (e.g., `auth_view.dart`, `product_list_view.dart`)
- **Widgets**: Reusable UI components organized by feature (e.g., `widgets/auth/`, `widgets/product/`)
- **Responsibilities**: Display data, handle user input, delegate to services
- **Dependency Access**: Inject via `getIt<Service>()` in `initState()`

**Example:**
```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final ProductService _productService;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();  // ✅ Inject via GetIt
  }
}
```

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
- **In-Memory** (Development):
  - `user_repository.dart` (InMemoryUserRepository)
  - `product_repository.dart` (InMemoryProductRepository)
  - `collection_repository.dart` (InMemoryCollectionRepository)
- **Firestore** (Production):
  - `firestore_user_repository.dart` (FirestoreUserRepository)
  - `firestore_product_repository.dart` (FirestoreProductRepository)
  - `firestore_collection_repository.dart` (FirestoreCollectionRepository)
- **Firebase Auth**:
  - `auth_repository.dart` (FirebaseAuthRepository)

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
├── service_locator.dart            # GetIt configuration with auto-switching
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
│   ├── *_repository.dart           # In-memory (dev)
│   └── firestore_*_repository.dart # Firestore (prod)
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
│   └── firebase_options.dart
└── features/                       # Reserved for future feature modules
```

## 5. Dependency Injection with GetIt

### Configuration (`service_locator.dart`)

The service locator automatically switches implementations based on environment:

```dart
// Auto-detects from .env file
final useFirestore = EnvironmentConfig.isProduction;

if (useFirestore) {
  // Production: Firestore repositories
} else {
  // Development: In-memory repositories
}
```

### Usage Pattern

**❌ NEVER do this:**
```dart
final service = ProductService(ProductRepository());  // Tight coupling!
```

**✅ ALWAYS do this:**
```dart
final service = getIt<ProductService>();  // Loose coupling via DI
```

### Registering New Dependencies

1. Define interface in `lib/interfaces/i_your_repository.dart`
2. Create implementations (in-memory and/or Firestore)
3. Register in `service_locator.dart`:
```dart
getIt.registerLazySingleton<IYourRepository>(
  () => YourRepository(firestore),  // or InMemoryYourRepository()
);
```
4. Inject where needed via `getIt<IYourRepository>()`

## 6. Environment Configuration

### Setup

Create a `.env` file in the project root:

```env
ENVIRONMENT=development  # or 'production'
TEST_USER_EMAIL=test@example.com
TEST_USER_PASSWORD=password123
```

### Behavior

- **`ENVIRONMENT=development`** (default):
  - Uses in-memory repositories
  - Data resets on app restart
  - Faster development, no network calls
  - Seeding service populates initial data

- **`ENVIRONMENT=production`**:
  - Uses Firestore repositories
  - Data persists in cloud
  - Requires Firebase setup

### Accessing Config

```dart
// In code
EnvironmentConfig.isProduction  // true if ENVIRONMENT=production
EnvironmentConfig.isDevelopment // true otherwise
EnvironmentConfig.testUserEmail // Access .env variables
```

## 7. Coding Standards

- File names: `lowercase_with_underscores.dart`
- Classes, variables, functions: `camelCase`
- Private members: Prefix with underscore `_privateMember`
- Indentation: 2 spaces
- Linting: `flutter_lints` (configured in `analysis_options.yaml`)
- Follow [Effective Dart](https://dart.dev/effective-dart/design) guidelines

## 8. Testing

*   Unit and widget tests are located in the `test/` directory
*   For testing, use in-memory repositories (already configured when not in production)
*   Run tests using `flutter test`

## 9. Build Commands

### Running the app
```bash
# Development mode (in-memory repositories)
flutter run --flavor development

# Production mode (Firestore repositories)
flutter run --flavor production
```

### Linting and testing
```bash
flutter analyze      # Check for issues
flutter test         # Run tests
dart format lib      # Format code
```

## 10. Adding New Features

Follow this pattern when adding features:

1. **Define the domain model** in `models/` with `toJson()`/`fromJson()`
2. **Create repository interface** in `interfaces/i_your_repository.dart`
3. **Implement repositories**:
   - In-memory version in `repositories/your_repository.dart`
   - Firestore version in `repositories/firestore_your_repository.dart`
4. **Create service** in `services/your_service.dart` for business logic
5. **Register in DI** container (`service_locator.dart`)
6. **Build UI** in `views/` and `widgets/`, injecting dependencies via GetIt

## 11. Firebase Setup

### Firestore Collections

- `users` - User profiles
- `products` - Food products
- `collections` - Product collections/baskets

### Security Rules

Remember to configure Firestore security rules for production deployment.

## 12. Git Workflow

*   Commit messages should be clear, concise, and descriptive
*   Avoid committing generated files (handled by `.gitignore`)
*   Run `flutter analyze` before committing

---

This document reflects the current architecture. Update as the project evolves.
