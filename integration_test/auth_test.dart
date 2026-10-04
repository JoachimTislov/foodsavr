import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const emulatorTestOptions = FirebaseOptions(
  apiKey: 'AIzaSyDummyKeyForDemoOnly',
  appId: '1:1234567890:android:dummyid123456',
  messagingSenderId: '',
  projectId: 'demo-project',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: emulatorTestOptions);
    }
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
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
}
