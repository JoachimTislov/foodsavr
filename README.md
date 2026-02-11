# FoodSavr

FoodSavr is designed to help people save food, time and money.

## Motivation

- Reduce food waste – Track product expiration dates, get reminders and prevent bad purchases
- Save time by elimating repetive tasks of checking inventory and cross-referencing recipes.
- Increase control and overview of food

[Core plan](./docs/core-plan.md)

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
   firebase emulators:start
   ```
   Emulator UI available at: `http://localhost:8081`

3. **Run the app** (in another terminal):
   ```bash
   make run-dev
   # or: flutter run --flavor development
   ```

The app automatically connects to emulators when `ENVIRONMENT=development` in `assets/.env`.

## Tech Stack

- Flutter
- Naturally Dart
- Material Design
- Firebase
    - Firestore
    - Authentication
- Google Cloud

## Getting Started

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Documentation

- [Flutter](https://docs.flutter.dev/)
    - [Material lib](https://api.flutter.dev/flutter/material/)
- [Firebase](https://firebase.google.com/docs/flutter/setup?platform=android)
- [Analyze options](https://dart.dev/guides/language/analysis-options)
