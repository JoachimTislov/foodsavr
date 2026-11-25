import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

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

/// Signs the primary client in and returns credentials for a second device
/// owned by the same user.
Future<({String email, String password})> signInEmulatorOwner() async {
  await ensureEmulatorInitialized();
  final email =
      'firestore-${DateTime.now().microsecondsSinceEpoch}@example.com';
  const password = 'emulator-test-password';
  await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  return (email: email, password: password);
}

Future<FirebaseFirestore> signedInEmulatorClient(
  String name, {
  ({String email, String password})? credentials,
}) async {
  final app = await Firebase.initializeApp(
    name: name,
    options: emulatorTestOptions,
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator(emulatorHost, authEmulatorPort);
  if (credentials == null) {
    await auth.signInAnonymously();
  } else {
    await auth.signInWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    );
  }
  final firestore = FirebaseFirestore.instanceFor(app: app);
  firestore.useFirestoreEmulator(emulatorHost, firestoreEmulatorPort);
  return firestore;
}

// Client rules deny reads and deletes of absent documents. Use the emulator
// admin endpoint for idempotent cleanup and to verify physical absence.
Uri _adminDocument(String path) => Uri.http(
  '$emulatorHost:$firestoreEmulatorPort',
  '/v1/projects/${emulatorTestOptions.projectId}/databases/(default)/documents/$path',
);

const _adminHeaders = {'Authorization': 'Bearer owner'};

Future<void> deleteEmulatorFixture(String path) async {
  final response = await http.delete(
    _adminDocument(path),
    headers: _adminHeaders,
  );
  if (response.statusCode != 200 && response.statusCode != 404) {
    throw StateError('Emulator cleanup failed for $path: ${response.body}');
  }
}

Future<bool> emulatorDocumentExists(String path) async {
  final response = await http.get(_adminDocument(path), headers: _adminHeaders);
  return switch (response.statusCode) {
    200 => true,
    404 => false,
    _ => throw StateError('Emulator lookup failed for $path: ${response.body}'),
  };
}
