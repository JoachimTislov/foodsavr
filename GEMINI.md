# Gemini CLI - foodsavr Project Guidelines

This document outlines the code structure, architectural principles, and general rules for the `foodsavr` Flutter project. Adhering to these guidelines ensures consistency, maintainability, and scalability of the codebase.

## 1. Project Overview

`foodsavr` is a Flutter application designed to [briefly describe the application's purpose - e.g., manage food inventory, track expiration dates, reduce food waste].

## 2. Tech Stack

*   **Framework**: Flutter
*   **Language**: Dart
*   **State Management**: [Based on project analysis, identify and specify the state management solution used, e.g., Provider, Riverpod, BLoC, GetX. If none is explicitly used or it's basic `setState`, mention that.]
*   **Authentication/Backend**: Firebase (via `firebase_core`, `firebase_auth`)
*   **Logging**: `logger` package

## 3. Directory Structure

The `lib/` directory is organized into a feature-first, layered architecture.

```
lib/
├───main.dart                 // Main entry point of the application
├───main_app_screen.dart      // Top-level widget for the main application flow
├───authentication/           // Feature module for user authentication
│   ├───application/          // Application layer: Use cases, business logic orchestration
│   │   └───auth_service.dart
│   ├───domain/               // Domain layer: Core entities, value objects, repository interfaces
│   │   ├───auth_repository.dart
│   │   └───user.dart
│   └───presentation/         // Presentation layer: UI widgets, views, state handling specific to UI
│       └───my_home_page.dart
└───data/                     // Infrastructure/Data layer: Repository implementations, data sources, models
    ├───auth_repository.dart  // Implementation of AuthRepository interface (from domain)
    ├───database.dart         // Database services or helpers
    ├───seeding.dart          // Initial data seeding
    └───models/               // Data models for serialization/deserialization
        ├───collection_model.dart
        └───product_model.dart
// Other feature modules will follow a similar structure (e.g., `lib/inventory/`, `lib/recipes/`)
```

### Key Principles:

*   **Feature-first**: Code related to a specific feature (e.g., `authentication`) is grouped together.
*   **Layered Architecture**: Within each feature, code is separated by architectural layers:
    *   **Domain**: Contains the enterprise-wide business rules. It's independent of other layers. (e.g., `lib/authentication/domain/`)
    *   **Application**: Contains application-specific business rules. Orchestrates domain objects to fulfill use cases. (e.g., `lib/authentication/application/`)
    *   **Presentation**: Handles UI logic, displaying data, and user interaction. (e.g., `lib/authentication/presentation/`)
    *   **Data/Infrastructure**: Deals with external concerns like databases, network requests, and implements domain interfaces (e.g., `lib/data/` for repository implementations).

## 4. Coding Standards and Linting

We adhere to strict coding standards enforced by `flutter_lints`. All code must pass analysis without warnings or errors.

*   Refer to `analysis_options.yaml` for specific enabled/disabled lint rules.
*   Run `flutter analyze` regularly to check for issues.
*   Prioritize clear, readable, and idiomatic Dart code.

## 5. Dependencies

Dependencies are managed in `pubspec.yaml`.

*   Always specify version ranges carefully to avoid breaking changes.
*   Run `flutter pub get` after modifying `pubspec.yaml`.
*   Avoid adding unnecessary dependencies.

## 6. Testing

*   Unit and widget tests are located in the `test/` directory, mirroring the `lib/` structure where appropriate.
*   Ensure adequate test coverage for new features and bug fixes.
*   Run tests using `flutter test`.

## 7. Git Workflow

*   Follow standard Git branching strategies (e.g., Git Flow, GitHub Flow).
*   Commit messages should be clear, concise, and descriptive.
*   Avoid committing generated files (e.g., `build/`, `.dart_tool/`) to the repository; these are handled by `.gitignore`.

---
This document is a living guide and may be updated as the project evolves.
