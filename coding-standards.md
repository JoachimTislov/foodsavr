# Coding Standards

- File names: lowercase_with_underscores.xxx
    - Everything else is in camelCase.
- Prefix underscores (_) for private members.
- Idiomatic Dart formatter (native)
    - Indentation: 2 spaces
- [dcm](https://github.com/CQLabs/homebrew-dcm) for linting ([website](https://dcm.dev/))

[Effective Dart](https://dart.dev/effective-dart/design)

## Architecture

The project follows a **3-tier layered architecture** with **dependency injection**:

### Core Principles:
- **Repository Pattern with Interfaces**: All data access through abstract interfaces
- **Dependency Injection**: GetIt service locator - never instantiate dependencies directly
- **Separation of Concerns**: UI → Services → Repositories → Models
- **Zero hard-coded values**: Use constants or configuration files

### Structure:
- **Presentation Layer**: `views/` and `widgets/` - UI components
  - Get dependencies via `getIt<Service>()` in `initState()`
  - No direct instantiation of services or repositories
- **Application Layer**: `services/` - Business logic, validation, orchestration
  - Depend on repository interfaces, not concrete implementations
- **Data Layer**: `repositories/` - Data access with multiple implementations
  - Abstract interfaces (`i_*_repository.dart`)
  - Firestore implementations (production persistence)
  - In-memory implementations (testing/seeding)
- **Domain Layer**: `models/` - Plain data classes with `toJson()`/`fromJson()`

### Library Folders:
- `constants/`: Application-wide constants
- `models/`: Data models with serialization
- `repositories/`: Data access interfaces and implementations
- `services/`: Business logic and orchestration
- `utils/`: Utility functions and helpers
- `widgets/`: Reusable UI components by feature
- `views/`: Full-screen UI components
- `service_locator.dart`: Dependency injection configuration

