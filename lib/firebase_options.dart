// Generated from the Firebase project my-foodsavr-store (web and Android apps).
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
    apiKey: 'AIzaSyDkNj5YrtkFAgAY2e2qEu3pHljSA6RU090',
    appId: '1:514586238925:web:e562b8b85d97417f83ae84',
    messagingSenderId: '514586238925',
    projectId: 'my-foodsavr-store',
    authDomain: 'my-foodsavr-store.firebaseapp.com',
    storageBucket: 'my-foodsavr-store.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAsu7CJwmAVOCfaBjZmu3bkS3UvZ0YiZS4',
    appId: '1:514586238925:android:366b08d42cf7d0b383ae84',
    messagingSenderId: '514586238925',
    projectId: 'my-foodsavr-store',
    storageBucket: 'my-foodsavr-store.firebasestorage.app',
  );
}
