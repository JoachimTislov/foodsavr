## Development setup

**Getting started**

If you are new to Flutter, we recommend reviewing these resources:

- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)
- [Full API Reference](https://api.flutter.dev/)

**Prerequisites**

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
    This project uses Android **product flavors** (`development` and `production`) to safely isolate environments. If you attempt to build or run the app without specifying a flavor, the build will fail (see [Gradle flavor troubleshooting](gradle-flavor-troubleshooting.md)).

    **Recommended (Using Make):**
    The easiest way to run the app is using the provided `Makefile`, which automatically handles flavors, environment variables, and starts the Firebase emulators if they aren't already running. Runs the default / first device available
    ```bash
    make run-dev    # Runs the development flavor with local emulators
    make run-prod   # Runs the production flavor
    ```

    **Manual CLI (Advanced):**
    If you must use the Flutter CLI directly, you **must** append the `--flavor` flag:
    ```bash
    flutter run --flavor development
    ```
    ```bash
    make dev-chrome
    # or: flutter run -d chrome
    ```
    The application connects to the emulators when `ENVIRONMENT=development` is 
    set in `assets/.env`.

### Anonymous auth (guest mode)

FoodSavr supports "Continue as guest" using Firebase Anonymous Authentication.
For local and production auth providers, ensure **Anonymous** sign-in is enabled
in Firebase Authentication (Sign-in method).

When a guest creates an account, FoodSavr upgrades the same Firebase user by
linking credentials (instead of creating a second user), which preserves the
guest user's existing app data.

Reference: https://firebase.google.com/docs/auth/web/anonymous-auth

### Facebook authentication

The Dart-side Facebook sign-in flow is implemented
(`FirebaseAuthService.signInWithFacebook`). To enable it on Android, expose the
Facebook credentials to the build:

1.  Set `FACEBOOK_APP_ID` and `FACEBOOK_CLIENT_TOKEN` in `.env` (or the build
    environment). The Android build only forwards allowlisted keys to the APK
    and generates the `facebook_app_id`, `facebook_client_token` and
    `fb_login_protocol_scheme` string resources that the manifest references
    for `com.facebook.CustomTabActivity`.
2.  In the Facebook app dashboard, add the Android platform with the FoodSavr
    package name (`com.foodsavr.app` / `com.foodsavr.app.development`) and key
    hashes.
3.  In Firebase Authentication, enable **Facebook** as a sign-in provider and
    paste the Facebook app ID and app secret.

Without `FACEBOOK_APP_ID` the build still succeeds (with a warning), but
Facebook sign-in fails at runtime.

Reference: https://developers.facebook.com/docs/facebook-login/android

### Common commands

| Command | Description |
| :--- | :---|
| `make run-dev` | Run in development mode. |
| `make clean` | Remove build artifacts and temporary files. |
| `make check` | Perform fast validation (analyze, fix, format, and test). |
| `make push` | Run full preflight checks and push to the remote repository. |


## Technical architecture

`foodsavr` is built using a modern, scalable stack and follows a 3-tier layered architecture.

- **Frontend:** Flutter and Dart using Material 3 design principles.
- **Backend:** Firebase Authentication and Cloud Firestore for real-time data.
- **Cloud:** Google Cloud Platform for serverless compute and infrastructure.

## Documentation

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)
- [Dart Analysis Options](https://dart.dev/guides/language/analysis-options)
- [Material 3 Components](https://m3.material.io/components)
- [Material lib](https://api.flutter.dev/flutter/material/)
