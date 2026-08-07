# Getting Started

Want to tinker with the code? Here's how to get a dev environment up and running.

## Prerequisites

You'll need the Flutter SDK on your machine. If you don't have it, the official guide is the way to go:

- [Flutter Installation Guide](https://flutter.dev/docs/get-started/install)

You'll also need a Firebase project.

### Firebase Setup

1.  **Create a Firebase Project:**
    Head over to the [Firebase Console](https://console.firebase.google.com/) and create a new project.

2.  **Install the Firebase CLI:**
    If you don't have it, install the Firebase command-line tool:
    ```sh
    npm install -g firebase-tools
    ```

3.  **Install the FlutterFire CLI:**
    This tool is essential for configuring Firebase in a Flutter project.
    ```sh
    dart pub global activate flutterfire_cli
    ```

4.  **Configure Firebase for the App:**
    From the root of the project, run the following command and follow the prompts to select your Firebase project:
    ```sh
    flutterfire configure
    ```
    This command will automatically generate `lib/firebase_options.dart` and configure your Android and iOS apps.

5.  **Download and Place Configuration Files (if needed):**
    In most cases, `flutterfire configure` handles everything. However, if you need to manually add the configuration files, download them from your Firebase project settings and place them as follows:
    - **Android:** `android/app/google-services.json`
    - **iOS:** `ios/Runner/GoogleService-Info.plist`

## Installation

1.  **Clone the repo:**
    ```sh
    git clone https://github.com/JoachimTislov/foodsavr.git
    cd foodsavr
    ```

2.  **Get packages:**
    ```sh
    flutter pub get
    ```

3.  **Run it!**
    ```sh
    flutter run
    ```
