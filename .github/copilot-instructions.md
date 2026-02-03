# FoodSavr - Copilot Instructions

FoodSavr is a Flutter application designed to help people reduce food waste by tracking product expiration dates, managing inventory, and cross-referencing recipes.

## Project Structure

### Library Organization

`lib/` uses a 3-tier architecture with dependency injection:

```
lib/
├── constants/           # Application-wide constants (e.g., environment_config.dart)
├── features/            # Feature modules (reserved for future expansion)
├── models/              # Data models with toJson/fromJson serialization
├── repositories/        # Data access layer
│   ├── i_*_repository.dart           # Repository interfaces (contracts)
│   ├── *_repository.dart             # In-memory implementations (for testing/seeding)
│   └── firestore_*_repository.dart   # Firestore implementations (production)
├── services/            # Business logic and orchestration
├── utils/               # Utility functions and helpers
├── views/               # Full-screen UI components
├── widgets/             # Reusable UI components organized by feature
└── service_locator.dart # Dependency injection configuration (GetIt)
```

**Key architectural principles:**
- **Repository Pattern with Interfaces**: All data access goes through abstract interfaces, allowing easy swapping of implementations
- **Dependency Injection**: Using GetIt service locator - dependencies are injected, never instantiated directly
- **Strict separation**: UI (views/widgets) → Business logic (services) → Data access (repositories) → Models
- **Dual implementations**: In-memory repos for testing/seeding, Firestore repos for production
- **Zero hard-coded values**: Use constants or configuration files

### Dependency Injection Pattern

**DO NOT directly instantiate services or repositories in widgets:**
```dart
// ❌ BAD - creates tight coupling
final service = ProductService(ProductRepository());

// ✅ GOOD - use service locator
final service = getIt<ProductService>();
```

**In widgets, get dependencies in `initState()`:**
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
    _productService = getIt<ProductService>();
  }
}
```

**To add new dependencies:**
1. Define interface in `repositories/i_*_repository.dart`
2. Create implementations (in-memory and/or Firestore)
3. Register in `service_locator.dart`
4. Inject via `getIt<YourType>()` where needed

## Build, Test, and Lint

### Running the app
```bash
# Development mode with flavor
make run-dev
# Or: flutter run --flavor development

# Production mode
make run-prod
# Or: flutter run --flavor production
```

### Testing
```bash
# All tests
make test
# Or: flutter test

# Single test file
flutter test test/path/to/test_file.dart
```

### Linting and formatting
```bash
# Analyze code (must pass with zero warnings/errors)
make analyze
# Or: flutter analyze

# Format code (2-space indentation, idiomatic Dart)
make fmt
# Or: dart format lib
```

### Other commands
```bash
make get          # flutter pub get
make clean        # flutter clean
make build-apk    # Build Android APK
make build-ios    # Build iOS app
make build-web    # Build web app
```

## Code Conventions

### Naming
- **Files**: `lowercase_with_underscores.dart`
- **Everything else**: `camelCase` (classes, variables, functions)
- **Private members**: Prefix with underscore (`_privateMember`)

### Linting
- Uses `flutter_lints` package (configured in `analysis_options.yaml`)
- Additional linting with [dcm](https://dcm.dev/) is recommended
- Follow [Effective Dart](https://dart.dev/effective-dart/design) guidelines

### Dependencies
- Managed in `pubspec.yaml`
- Run `flutter pub get` after any changes
- Always specify version ranges to avoid breaking changes

## Tech Stack

- **Framework**: Flutter (SDK ^3.10.7)
- **UI**: Material Design
- **Backend**: Firebase (Firestore for data, Authentication)
- **Dependency Injection**: GetIt service locator
- **Localization**: `easy_localization` with translations in `assets/translations/`
- **Logging**: `logger` package
- **Environment**: `flutter_dotenv` for environment configuration

## Data Persistence

The app uses **Firestore** for data persistence by default:
- User data → `users` collection
- Products → `products` collection  
- Collections → `collections` collection

All models have `toJson()`/`fromJson()` methods for Firestore serialization.

**In-memory repositories** are also available (see `service_locator.dart`) for:
- Testing (no external dependencies)
- Initial seeding
- Development without Firestore connection

## Working with the Codebase

### Repository Pattern
All data access goes through repository **interfaces**:
- `IAuthRepository` - Authentication (impl: FirebaseAuthRepository)
- `IUserRepository` - User data (impl: FirestoreUserRepository, InMemoryUserRepository)
- `IProductRepository` - Product management (impl: FirestoreProductRepository, InMemoryProductRepository)
- `ICollectionRepository` - Collection management (impl: FirestoreCollectionRepository, InMemoryCollectionRepository)

**Key benefit**: Swap implementations without changing business logic (e.g., Firestore → SQL)

### Services Layer
Business logic lives in services (injected via GetIt):
- `AuthService` - Authentication orchestration + validation
- `ProductService` - Product operations + logging
- `SeedingService` - Initial data seeding

Services orchestrate repositories and contain validation/business rules.

### UI Components
- **Views**: Full screens in `views/` (e.g., `auth_view.dart`, `product_list_view.dart`)
  - Get services via `getIt<Service>()` in `initState()`
- **Widgets**: Reusable components in `widgets/` organized by feature domain
  - `widgets/auth/` - Authentication-related widgets
  - `widgets/product/` - Product-related widgets

### Adding New Features
1. Define domain models in `models/` with serialization
2. Create repository interface in `repositories/i_*_repository.dart`
3. Implement repository (Firestore and/or in-memory)
4. Create service in `services/` for business logic
5. Register in `service_locator.dart`
6. Build UI in `views/` and `widgets/`, injecting dependencies via GetIt
