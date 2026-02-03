# FoodSavr - Copilot Instructions

FoodSavr is a Flutter application designed to help people reduce food waste by tracking product expiration dates, managing inventory, and cross-referencing recipes.

## Project Structure

The app folder is at `/app/` (not root). All Flutter commands must be run from `/app/`.

### Library Organization

`lib/` uses a hybrid architecture combining feature-first modules with layered separation:

```
lib/
├── constants/           # Application-wide constants (e.g., environment_config.dart)
├── features/            # Feature modules (currently empty, planned for future)
├── models/              # Data models for serialization/deserialization
├── repositories/        # Data access layer (interfaces and implementations)
├── services/            # Business logic and data services
├── utils/               # Utility functions and helpers
├── views/               # Composite UI screens (auth_view, product_list_view, main_view)
└── widgets/             # Reusable UI components organized by feature (auth/, product/)
```

**Key architectural principles:**
- **DDD (Domain-Driven Design)**: Domain entities are independent; repository interfaces define contracts
- **Strict separation**: UI (views/widgets) → Business logic (services) → Data access (repositories) → Models
- **Feature folders**: The `features/` directory is intended for future modular features using Domain/Application/Presentation/Data layers (as documented in GEMINI.md)
- **Zero hard-coded values**: Use constants or configuration files (see `constants/environment_config.dart`)

## Build, Test, and Lint

All commands run from `/app/` directory:

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
- Managed in `app/pubspec.yaml`
- Run `flutter pub get` after any changes
- Always specify version ranges to avoid breaking changes

## Tech Stack

- **Framework**: Flutter (SDK ^3.10.7)
- **UI**: Material Design
- **Backend**: Firebase (Firestore, Authentication via `firebase_core`, `firebase_auth`)
- **Localization**: `easy_localization` with translations in `assets/translations/`
- **Logging**: `logger` package
- **Environment**: `flutter_dotenv` for environment configuration

## Working with the Codebase

### Repository Pattern
All data access goes through repository interfaces:
- `auth_repository.dart` - Authentication
- `user_repository.dart` - User data
- `product_repository.dart` - Product management
- `collection_repository.dart` - Collection management

### Services Layer
Business logic lives in services:
- `auth_service.dart` - Authentication orchestration
- `user_service.dart` - User operations
- `product_service.dart` - Product operations

### UI Components
- **Views**: Full screens in `views/` (e.g., `auth_view.dart`, `product_list_view.dart`)
- **Widgets**: Reusable components in `widgets/` organized by feature domain
  - `widgets/auth/` - Authentication-related widgets
  - `widgets/product/` - Product-related widgets

### Adding New Features
When adding significant new features, consider creating a feature module in `features/` with Domain/Application/Presentation/Data layers (see GEMINI.md for the intended structure).
