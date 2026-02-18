---
name: creation
description: Guide for implementing new features, widgets, and logic in the project's source code.
---

# Source Code Creation Guide

Follow these instructions for implementing new features, widgets, and business logic in the FoodSavr project.

1. **Follow 3-Tier Architecture:**
   - **UI Layer (`views/`, `widgets/`):** Create views and reusable widgets that delegate to services.
   - **Application Layer (`services/`):** Implement business logic and orchestrate use cases.
   - **Data Layer (`repositories/`, `models/`, `interfaces/`):** Define models, repository contracts, and Firestore implementations.

2. **Define the Domain Model:**
   - Create models in `lib/models/` with `toJson()` and `fromJson()` for Firestore serialization.

3. **Establish Repository Contracts:**
   - Define abstract repository interfaces in `lib/interfaces/`.
   - Implement the repository in `lib/repositories/`, typically using Firestore.

4. **Implement Business Logic in Services:**
   - Create services in `lib/services/` to handle validation, orchestration, and business rules.
   - Inject repository interfaces into services, not concrete implementations.

5. **Register in Service Locator:**
   - Add new services and repositories to the dependency injection container in `lib/service_locator.dart`.

6. **Adhere to Naming Conventions:**
   - File names: `snake_case.dart`
   - Classes: `PascalCase`
   - Variables/Functions: `camelCase`
   - Private members: `_prefixedWithUnderscore`
