---
name: creation
description: Use this skill when asked to implement new features
---

# Source Code Creation Guide

Follow these instructions for implementing new features, widgets, and business logic

1. **Follow 4-Tier Architecture:**
   - **UI Layer (`views/`, `widgets/`):** Create views and reusable widgets that delegate to services.
   - **Application Layer (`services/`):** Implement business logic and orchestrate use cases.
   - **Data Layer (`repositories/`, `models/`, `interfaces/`):** Define models, repository contracts, and Firestore implementations.

2. **Define the Domain Model:**
   - Create models in `lib/models/` using `toJson()` and `fromJson()` for Firestore serialization.

3. **Establish Repository Contracts:**
   - Define abstract repository interfaces in `lib/interfaces/`.
   - Implement the repository in `lib/repositories/`, typically using Firestore.

4. **Implement Business Logic in Services:**
   - Create services in `lib/services/` to handle validation and business rules.
   - Inject repository interfaces into services via constructor injection.

5. **State Management and DI:**
   - Use GetIt for dependency injection, configured in `lib/injection.dart`.
   - Use `watch_it` for reactive state management in widgets (e.g., `WatchingWidget`).
   - Use `@injectable` on repository and service implementations and run `dart run build_runner build --delete-conflicting-outputs` to generate DI code.
   - UI widgets should consume state using `watchIt<T>()`, `watchValue((MyService s) => s.someValue)`, etc.

6. **Adhere to Naming Conventions:**
   - File names: `snake_case.dart`
   - Classes: `PascalCase`
   - Variables/Functions: `camelCase`
   - Private members: `_prefixedWithUnderscore`
