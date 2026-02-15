# FoodSavr - Copilot Instructions

FoodSavr is a Flutter application designed to help people reduce food waste by tracking product expiration dates, managing inventory, and cross-referencing recipes.

## Project Structure

### Library Organization

`lib/` uses a 3-tier architecture with dependency injection:

```
lib/
├── constants/           # Application-wide constants (e.g., environment_config.dart)
├── features/            # Feature modules (reserved for future expansion)
├── interfaces/          # Repository interfaces (contracts)
│   ├── i_auth_repository.dart
│   ├── i_user_repository.dart
│   ├── i_product_repository.dart
│   └── i_collection_repository.dart
├── models/              # Data models with toJson/fromJson serialization
├── repositories/        # Data access layer (Firestore implementations)
│   ├── auth_repository.dart             # Firebase Auth implementation
│   └── firestore_*_repository.dart      # Firestore implementations
├── services/            # Business logic and orchestration
├── utils/               # Utility functions and helpers
├── views/               # Full-screen UI components
├── widgets/             # Reusable UI components organized by feature
├── firebase_options.dart # Firebase configuration for all platforms
└── service_locator.dart # Dependency injection configuration (GetIt)
```

**Key architectural principles:**
- **Repository Pattern with Interfaces**: All data access goes through abstract interfaces, allowing easy swapping of implementations
- **Dependency Injection**: Using GetIt service locator - dependencies are injected, never instantiated directly
- **Strict separation**: UI (views/widgets) → Business logic (services) → Data access (repositories) → Models
- **Emulator-Driven Development**: Uses Firebase emulators (Auth, Firestore) in development for fast iteration
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
1. Define interface in `interfaces/i_*_repository.dart`
2. Create Firestore implementation in `repositories/firestore_*_repository.dart`
3. Register in `service_locator.dart`
4. Inject via `getIt<YourType>()` where needed

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
  - Uses Firebase emulators in development (Auth: localhost:9099, Firestore: localhost:8080)
  - Emulator UI available at http://localhost:8081
- **Dependency Injection**: GetIt service locator
- **Localization**: `easy_localization` with translations in `assets/translations/`
- **Logging**: `logger` package
- **Environment**: Environment configuration via `assets/.env` file

## Data Persistence

The app uses **Firebase Firestore** for all data persistence:
- User data → `users` collection
- Products → `products` collection  
- Collections → `collections` collection

All models have `toJson()`/`fromJson()` methods for Firestore serialization.

### Development vs Production

**Development** (`ENVIRONMENT=development` in `assets/.env`):
- Connects to Firebase emulators (localhost)
- Data persists in emulator, can be exported/imported
- Fast iteration without affecting production data
- Run `firebase emulators:start` before launching app

**Production** (`ENVIRONMENT=production` in `assets/.env`):
- Connects to production Firebase project
- Data persists in cloud Firestore
- Requires proper Firebase project setup and credentials

## Working with the Codebase

### Repository Pattern
All data access goes through repository **interfaces**:
- `IAuthRepository` - Authentication (impl: FirebaseAuthRepository)
- `IUserRepository` - User data (impl: FirestoreUserRepository)
- `IProductRepository` - Product management (impl: FirestoreProductRepository)
- `ICollectionRepository` - Collection management (impl: FirestoreCollectionRepository)

**Key benefit**: Swap implementations without changing business logic (e.g., add caching layer, switch to different database)

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
2. Create repository interface in `interfaces/i_*_repository.dart`
3. Implement Firestore repository in `repositories/firestore_*_repository.dart`
4. Create service in `services/` for business logic
5. Register in `service_locator.dart`
6. Build UI in `views/` and `widgets/`, injecting dependencies via GetIt
7. Test with Firebase emulators before deploying to production
