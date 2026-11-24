import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

const emulatorTestOptions = FirebaseOptions(
  apiKey: 'AIzaSyDummyKeyForDemoOnly',
  appId: '1:1234567890:android:dummyid123456',
  messagingSenderId: '',
  projectId: 'demo-project',
);

const _emulatorHost = String.fromEnvironment(
  'AUTH_TEST_EMULATOR_HOST',
  defaultValue: 'localhost',
);
const _strictRules = bool.fromEnvironment('AUTH_TEST_STRICT_RULES');

const _firestorePort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: emulatorTestOptions);
    }
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(
      _emulatorHost,
      _firestorePort,
    );
  });

  tearDown(() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      await user.delete();
    }
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('sign up, sign in and sign out against Auth emulator', (
    tester,
  ) async {
    final auth = FirebaseAuth.instance;
    final email =
        'it-user-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'password123';

    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    expect(credential.user, isNotNull);
    expect(credential.user!.email, email);

    await auth.signOut();
    expect(auth.currentUser, isNull);

    final signedIn = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    expect(signedIn.user!.email, email);

    await auth.signOut();
    expect(auth.currentUser, isNull);
  });

  testWidgets('sign in with wrong password fails', (tester) async {
    final auth = FirebaseAuth.instance;
    final email =
        'it-user-${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'password123';

    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    expect(credential.user, isNotNull);

    await expectLater(
      auth.signInWithEmailAndPassword(email: email, password: 'wrong'),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(auth.currentUser, isNotNull);
    await credential.user!.delete();
    await auth.signOut();
    expect(auth.currentUser, isNull);
  });
  testWidgets('atomically deletes more than 500 account documents', (
    tester,
  ) async {
    await ServiceLocator().registerDependencies();
    addTearDown(getIt.reset);
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final email = 'delete-${DateTime.now().microsecondsSinceEpoch}@example.com';
    const password = 'password123';
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    for (final (start, end) in [(0, 500), (500, 501)]) {
      final batch = firestore.batch();
      for (var index = start; index < end; index++) {
        batch.set(firestore.collection('products').doc(), {
          'name': 'Product $index',
          'userId': uid,
        });
      }
      await batch.commit();
    }
    await firestore.collection('collections').add({
      'name': 'Inventory',
      'userId': uid,
    });
    final preferences = firestore.doc('users/$uid/settings/preferences');
    await preferences.set({'expiringSoonDays': 5});
    await firestore.doc('users/$uid').set({'email': email});

    const database =
        'http://$_emulatorHost:$_firestorePort/v1/projects/demo-project'
        '/databases/(default)/documents';
    // Use the emulator-only admin identity to arrange and inspect rule failures.
    const headers = {
      'Authorization': 'Bearer owner',
      'Content-Type': 'application/json',
    };
    final authService = getIt<IAuthService>();
    if (_strictRules) {
      // The owner can query this global document by userId but cannot delete it.
      // Sort after auto IDs so the old paged cleanup would commit first.
      final blocker = Uri.parse('$database/products/~blocked-$uid');
      final seeded = await http.patch(
        blocker,
        headers: headers,
        body: jsonEncode({
          'fields': {
            'userId': {'stringValue': uid},
            'isGlobal': {'booleanValue': true},
          },
        }),
      );
      expect(seeded.statusCode, 200, reason: seeded.body);
      try {
        await expectLater(
          authService.deleteAccount(reauthenticate: true, password: password),
          throwsA(
            isA<FirebaseException>().having(
              (error) => error.code,
              'code',
              'permission-denied',
            ),
          ),
        );
        expect(auth.currentUser?.uid, uid);
        const server = GetOptions(source: Source.server);
        for (final (name, count) in [('products', 502), ('collections', 1)]) {
          final docs = await firestore
              .collection(name)
              .where('userId', isEqualTo: uid)
              .get(server);
          expect(docs.size, count);
        }
        expect((await preferences.get(server)).exists, isTrue);
        expect((await firestore.doc('users/$uid').get(server)).exists, isTrue);
      } finally {
        final removed = await http.delete(blocker, headers: headers);
        expect(removed.statusCode, 200, reason: removed.body);
      }
    }

    await authService.deleteAccount(reauthenticate: true, password: password);
    expect(auth.currentUser, isNull);

    for (final collection in ['products', 'collections']) {
      final response = await http.post(
        Uri.parse('$database:runQuery'),
        headers: headers,
        body: jsonEncode({
          'structuredQuery': {
            'from': [
              {'collectionId': collection},
            ],
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': 'userId'},
                'op': 'EQUAL',
                'value': {'stringValue': uid},
              },
            },
          },
        }),
      );
      expect(response.statusCode, 200, reason: response.body);
      final rows = jsonDecode(response.body) as List<dynamic>;
      expect(
        rows.where((row) => (row as Map).containsKey('document')),
        isEmpty,
      );
    }
    for (final path in ['users/$uid', preferences.path]) {
      final response = await http.get(
        Uri.parse('$database/$path'),
        headers: headers,
      );
      expect(response.statusCode, 404, reason: response.body);
    }
  });
}
