---
name: maintenance
description: Use this skill when tasked to refactor, organize, or restructure the source code for better maintainability and adherence to engineering principles.
---

# Source Code Management Guide

Follow these instructions for refactoring and maintaining the FoodSavr project.

1. **Refactor Complex Widgets and Services:**
   - Break down large build methods into smaller, private widget classes.
   - Consolidate business logic into clear abstractions within services.
   - Extract common UI components into reusable widgets in `lib/widgets/common/`.

2. **Manage Dependencies and Decoupling:**
   - Use constructor injection for all services and repositories.
   - Depend on repository interfaces (`i_product_repository.dart`) instead of concrete implementations.
   - Use `@injectable` to register classes and let the generator handle DI.
   - Use Riverpod providers as the primary way to expose state to UI (`ref.watch` / `ref.read`), and keep `getIt<T>()` usage in provider or app setup wiring.
   - Ensure a clean separation between UI, services, and data layers.

3. **Organize According to Layers:**
   - Maintain the standard directory structure (views, widgets, services, repositories, models, interfaces).
   - Use feature-based subdirectories for larger functional modules.

4. **Apply Engineering Principles:**
   - Follow SOLID principles for maintainability and scalability.
   - Use DRY (Don't Repeat Yourself) to minimize code duplication.
   - Maintain idiomatic code quality as defined in the project's coding standards.
