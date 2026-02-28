# FoodSavr

`foodsavr` is a mobile and web application designed to help you reduce food 
waste, save time, and manage your grocery expenses efficiently. By tracking 
inventory and automating meal planning, the application ensures you always know 
what you have and what you need.

## Motivation

- **Reduce food waste:** Track product expiration dates and receive timely 
  reminders to use items before they spoil.
- **Save time:** Eliminate the need for manual inventory checks by 
  synchronizing your stock with recipes and meal plans.
- **Increase control:** Gain a clear overview of your food supplies and 
  spending habits across multiple storage locations.

For more details on the project strategy, see the 
[Core plan](./docs/plan/core.md).

## Development setup

### Prerequisites

- **Flutter SDK:** Version `^3.10.7` is required.
- **Firebase CLI:** Install via npm: `npm install -g firebase-tools`.

### Firebase emulator setup

`foodsavr` uses the Firebase Emulator Suite for local development to avoid 
unnecessary cloud costs and ensure a consistent environment.

1.  **Initialize Firebase (first time only):**
    ```bash
    firebase login
    firebase init emulators
    ```
    - Authentication Emulator: Port 9099
    - Firestore Emulator: Port 8080
    - Emulator UI: Port 8081

2.  **Start the emulators:**
    ```bash
    make start-firebase-emulators
    # or: firebase emulators:start
    ```
    Access the Emulator UI at `http://localhost:8081`.

3.  **Run the application:**
    ```bash
    make dev-chrome
    # or: flutter run -d chrome
    ```
    The application connects to the emulators when `ENVIRONMENT=development` is 
    set in `assets/.env`.

### Common commands

| Command | Description |
| :--- | :--- |
| `make dev-*` | Run in development mode (e.g., `dev-chrome`, `dev-android`). |
| `make clean` | Remove build artifacts and temporary files. |
| `make check` | Perform fast validation (analyze, fix, format, and test). |
| `make push` | Run full preflight checks and push to the remote repository. |

## Technical architecture

`foodsavr` is built using a modern, scalable stack and follows a 4-tier
layered architecture.

- **Frontend:** Flutter and Dart using Material 3 design principles.
- **Backend:** Firebase Authentication and Cloud Firestore for real-time data.
- **Cloud:** Google Cloud Platform for serverless compute and infrastructure.

## Documentation

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)
- [Dart Analysis Options](https://dart.dev/guides/language/analysis-options)
- [Material 3 Components](https://m3.material.io/components)
- [Material lib](https://api.flutter.dev/flutter/material/)

## Getting started

If you are new to Flutter, we recommend reviewing these resources:

- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)
- [Full API Reference](https://api.flutter.dev/)
