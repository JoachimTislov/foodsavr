# Coding Standards

- File names: lowercase_with_underscores.xxx
    - Everything else is in camelCase.
- Prefix underscores (_) for private members.
- Idiomatic Dart formatter (native)
    - Indentation: 2 spaces
- [dcm](https://github.com/CQLabs/homebrew-dcm) for linting ([website](https://dcm.dev/))

[Effective Dart](https://dart.dev/effective-dart/design)

## Architecture

- DDD (Domain-Driven Design) principles should be followed.
- Modular structure: Code should be organized into modules based on features or domains.
- Strict typing through interface, abstract, generic and concrete classes.
- Zero hard-coded values: Use constants or configuration files.
- Separation of concerns: UI, business logic, and data layers should be clearly separated.
- library folders (source code) structure:
    - constants/: Application-wide constants
    - features/: Feature-specific code
    - `models/`: Data models
    - repositories/: Data access layer
    - `services/`: Business logic and data services
    - `utils/`: Utility functions and helpers
    - `widgets/`: Reusable UI components
    - views/`: Composite UI components
    - state/: State management files

