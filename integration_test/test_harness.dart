import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

const emulatorTestOptions = FirebaseOptions(
  apiKey: 'AIzaSyDummyKeyForDemoOnly',
  appId: '1:1234567890:android:dummyid123456',
  messagingSenderId: '',
  projectId: 'demo-project',
);

const emulatorHost = String.fromEnvironment(
  'AUTH_TEST_EMULATOR_HOST',
  defaultValue: 'localhost',
);

const authEmulatorPort = 9099;

const firestoreEmulatorPort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);

bool _emulatorsConfigured = false;

/// Initializes Firebase and points Auth and Firestore at the local emulators
/// exactly once per Dart isolate so consolidated test runners never reconfigure
/// Firestore after its first use.
Future<void> ensureEmulatorInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: emulatorTestOptions);
  }
  if (_emulatorsConfigured) {
    return;
  }
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, authEmulatorPort);
  FirebaseFirestore.instance.useFirestoreEmulator(
    emulatorHost,
    firestoreEmulatorPort,
  );
  _emulatorsConfigured = true;
}
