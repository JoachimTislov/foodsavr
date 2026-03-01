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
   - Always run `make codegen` after modifying models.

3. **Establish Repository Contracts:**
   - Define abstract repository interfaces in `lib/interfaces/`.
   - Implement the repository in `lib/repositories/`, typically using Firestore.

4. **Implement Business Logic in Services/Providers:**
   - Create services in `lib/services/` to handle validation and business rules.
   - Use Riverpod `@riverpod` annotation for providers.
   - Inject repository interfaces into services or providers via constructor injection or `ref.watch`.

5. **State Management and DI:**
   - Use Riverpod for application state management (AsyncNotifier, Notifier).
   - Use `@injectable` for repository implementations.
   - Run `make codegen` to generate both Riverpod and Injectable code.
   - UI should consume state via `ConsumerWidget` or `ref.watch`.

6. **Adhere to Naming Conventions:**
   - File names: `snake_case.dart`
   - Classes: `PascalCase`
   - Variables/Functions: `camelCase`
   - Private members: `_prefixedWithUnderscore`
