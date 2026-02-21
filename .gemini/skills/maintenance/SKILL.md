---
name: maintenance
description: Guide for refactoring, organizing, and maintaining the project's source code.
---

# Source Code Management Guide

Follow these instructions for refactoring and maintaining the FoodSavr project.

1. **Refactor Complex Widgets and Services:**
   - Break down large build methods into smaller, private widget classes.
   - Consolidate business logic into clear abstractions within services.
   - Extract common UI components into reusable widgets in `lib/widgets/common/`.

2. **Manage Dependencies and Decoupling:**
   - Always use the `getIt` service locator to inject dependencies.
   - Depend on repository interfaces, not concrete implementations.
   - Ensure a clean separation between UI, services, and data layers.

3. **Organize According to Layers:**
   - Maintain the standard directory structure (views, widgets, services, repositories, models, interfaces).
   - Use feature-based subdirectories for larger functional modules.

4. **Apply Engineering Principles:**
   - Follow SOLID principles for maintainability and scalability.
   - Use DRY (Don't Repeat Yourself) to minimize code duplication.
   - Maintain idiomatic code quality as defined in the project's coding standards.
