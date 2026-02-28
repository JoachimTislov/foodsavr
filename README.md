# FoodSavr

FoodSavr is designed to help people save food, time and money.

## Motivation

- Reduce food waste – Track product expiration dates, get reminders and prevent bad purchases
- Save time by eliminating repetitive tasks of checking inventory and cross-referencing recipes.
- Increase control and overview of food

[Core plan](./docs/plan/core.md)

## Development Setup

### Prerequisites

- Flutter SDK (^3.10.7)
- Firebase CLI: `npm install -g firebase-tools`

### Firebase Emulator Setup

1. **Initialize Firebase** (first time only):
   ```bash
   firebase login
   firebase init emulators
   ```
    - Authentication Emulator (port 9099)
    - Firestore Emulator (port 8080)
    - Emulator UI (port 8081)

2. **Start emulators**:
   ```bash
   make start-firebase-emulators
   # or firebase emulators:start
   ```
   Emulator UI available at: `http://localhost:8081`

3. **Run the app** (in another terminal):
   ```bash
   make dev-chrome
   # or: flutter run -d chrome
   ```

The app automatically connects to emulators when `ENVIRONMENT=development` in `assets/.env`.

### Useful commands

```bash
make dev-*         # Run in development mode (dev-chrome, dev-android)
make clean         # Clean build artifacts
make check         # Fast validation (analyze/fix/fmt/test/locale-check)
make push          # preflight + check-full + git push
make pr-comments-active PR=X            # List one active PR thread
make pr-comments-resolve-active PR=X    # Resolve one active PR thread
make pr-comments-resolve-outdated PR=X  # Resolve one outdated PR thread
```

## Tech Stack

Google

### Details

- Flutter
- Naturally Dart
- Material Design
- Firebase
    - Firestore
    - Authentication
- Google Cloud

## Documentation

- [Flutter](https://docs.flutter.dev/)
    - [Material lib](https://api.flutter.dev/flutter/material/)
- [Firebase](https://firebase.google.com/docs/flutter/setup?platform=android)
- [Analyze options](https://dart.dev/guides/language/analysis-options)

## Getting Started

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

