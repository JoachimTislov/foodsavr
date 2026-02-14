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
- **One widget per file**: All widgets must be in their own file in the `widgets/` folder
- **No private widget methods in views**: Extract to separate widget files in `widgets/` folder
- **Use configuration classes directly**: No thin wrapper helpers - use config classes like `ProductCategory`, `CollectionConfig` directly
- **Keep view files concise**: Target under 200 lines by extracting reusable widgets
- **Business logic in models/services**: Not in widget build methods

### Structure:
- **Presentation Layer**: `views/` and `widgets/` - UI components
  - Get dependencies via `getIt<Service>()` in `initState()`
  - No direct instantiation of services or repositories
  - **Views**: Full-screen components that compose widgets
  - **Widgets**: Reusable UI components, one per file, organized by feature
  - No private widget builder methods (e.g., `_buildSomething()`) - extract to separate widget files
- **Application Layer**: `services/` - Business logic, validation, orchestration
  - Depend on repository interfaces, not concrete implementations
- **Data Layer**: `repositories/` - Data access with multiple implementations
  - Abstract interfaces (`i_*_repository.dart`)
  - Firestore implementations (production persistence)
  - In-memory implementations (testing/seeding)
- **Domain Layer**: `models/` - Plain data classes with `toJson()`/`fromJson()`
  - Include computed properties for business logic (e.g., `product.status`)

### Library Folders:
- `constants/`: Application-wide constants and configuration classes
  - Configuration classes like `ProductCategory`, `CollectionConfig`, `Material3Config`
  - Use these directly instead of creating thin wrapper helpers
- `models/`: Data models with serialization and computed properties
- `repositories/`: Data access interfaces and implementations
- `services/`: Business logic and orchestration
- `utils/`: Pure utility functions (date formatting, etc.)
  - Avoid thin wrappers that just delegate to config classes
- `widgets/`: Reusable UI components by feature, **one widget per file**
  - `widgets/common/`: Shared widgets (EmptyStateWidget, ErrorStateWidget, etc.)
  - `widgets/product/`: Product-specific widgets
  - `widgets/collection/`: Collection-specific widgets
  - `widgets/auth/`: Authentication widgets
- `views/`: Full-screen UI components that compose widgets
  - Should be concise, primarily composing widgets
  - Extract complex UI into separate widget files
- `service_locator.dart`: Dependency injection configuration

### Widget Development Guidelines:
1. **One widget per file**: Never define multiple widget classes in a single file
2. **Extract private builders**: If you find yourself writing `Widget _buildSomething()`, create a new widget file instead
3. **Reusability**: Design widgets to be reusable with parameters
4. **Keep widgets focused**: Each widget should have a single responsibility
5. **Use config classes**: Directly use `ProductCategory.getIcon()`, `CollectionConfig.getColor()`, etc.
6. **Business logic belongs elsewhere**: Status checks, data transformations go in models/services

### Example - Good vs Bad:

**Bad** (private builder in view):
```dart
class MyView extends StatelessWidget {
  Widget _buildCard() { ... }  // ❌ Private builder method
}
```

**Good** (extracted widget):
```dart
// my_view.dart
class MyView extends StatelessWidget {
  build() => MyCard(...);  // ✅ Uses extracted widget
}

// widgets/my_card.dart
class MyCard extends StatelessWidget { ... }  // ✅ Separate file
```

**Bad** (thin wrapper helper):
```dart
class SomeHelper {
  static getIcon(type) => ConfigClass.getIcon(type);  // ❌ Unnecessary wrapper
}
```

**Good** (direct config usage):
```dart
ProductCategory.getIcon(category)  // ✅ Direct usage
CollectionConfig.getColor(type, colorScheme)  // ✅ Direct usage
```

