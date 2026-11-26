// Firebase client options of the deployment environment, from compile-time
// defines: no project ids are tracked (the repository is stateless).
//
// `make setup` writes the defines to the gitignored `.agents/state/firebase.defines.json`
// (scripts/firebase_options.py) and `make run-*`/`make build-*` pass it with
// `--dart-define-from-file`. Hosting deploys regenerate this file from the
// environment's project at build time (scripts/web/write_web_config.py).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// Whether the build received a Firebase project.
  static const bool configured = bool.hasEnvironment('FIREBASE_PROJECT_ID');

  static FirebaseOptions get currentPlatform {
    if (!configured) {
      throw StateError(
        'Firebase options are not configured. Run `make setup` (writes '
        '.agents/state/firebase.defines.json), or use the emulators (`make run-dev`).',
      );
    }
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String? _storageBucket =
      bool.hasEnvironment('FIREBASE_STORAGE_BUCKET')
      ? String.fromEnvironment('FIREBASE_STORAGE_BUCKET')
      : null;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_WEB_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_WEB_APP_ID'),
    messagingSenderId: _senderId,
    projectId: _projectId,
    authDomain: bool.hasEnvironment('FIREBASE_AUTH_DOMAIN')
        ? String.fromEnvironment('FIREBASE_AUTH_DOMAIN')
        : null,
    storageBucket: _storageBucket,
    measurementId: bool.hasEnvironment('FIREBASE_MEASUREMENT_ID')
        ? String.fromEnvironment('FIREBASE_MEASUREMENT_ID')
        : null,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: _senderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );
}
