import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foodsavr/main.dart';
import 'package:foodsavr/service_locator.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock Firebase initialization for testing
    setupFirebaseAuthMocks();
    await Firebase.initializeApp();

    // Setup service locator for tests
    await registerDependencies(
      FirebaseAuth.instance,
      FirebaseFirestore.instance,
    );
  });

  testWidgets('Renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyApp()));

    // Verify that the login screen is rendered.
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });
}

// Mock Firebase for testing
void setupFirebaseAuthMocks() {
  // This is a simplified mock - in production you'd use firebase_auth_mocks package
}
