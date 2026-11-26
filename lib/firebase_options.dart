// Generated from the Firebase project foodsavr-test (web and Android apps).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyASwg08GwQp30lwM61tO8-se6BbPW2lpqg',
    appId: '1:965790789072:web:95b2627567ba28b9ae1dd5',
    messagingSenderId: '965790789072',
    projectId: 'foodsavr-test',
    authDomain: 'foodsavr-test.firebaseapp.com',
    storageBucket: 'foodsavr-test.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB_Q32ZYB8rvySrlf9bxM0P12KWiMlktlU',
    appId: '1:965790789072:android:fdc53a86cd602616ae1dd5',
    messagingSenderId: '965790789072',
    projectId: 'foodsavr-test',
    storageBucket: 'foodsavr-test.firebasestorage.app',
  );
}
