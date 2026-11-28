import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/widgets/settings/password_action_tile.dart';
import 'package:mocktail/mocktail.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthService auth;

  setUp(() async {
    await setUpSettingsWidgetTest();
    auth = MockAuthService();
  });

  void useUser(User? user) => when(() => auth.currentUser).thenReturn(user);

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('offers to add a password to a social-only account', (
    tester,
  ) async {
    final social = signedInUser([providerInfo('google.com')]);
    final linked = signedInUser([
      providerInfo('google.com'),
      providerInfo('password'),
    ]);
    useUser(social);
    when(
      () => auth.linkPasswordCredential(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => useUser(linked));
    var changes = 0;
    await pumpSettingsWidget(
      tester,
      PasswordActionTile(authService: auth, onChanged: () => changes++),
    );

    expect(find.text('Add password'), findsOneWidget);
    expect(find.text('Forgot Password'), findsNothing);

    await tester.tap(find.text('Add password'));
    await tester.pumpAndSettle();
    await tester.enterText(field('New password'), 'secret-123');
    await tester.enterText(field('Confirm password'), 'secret-123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(
      () => auth.linkPasswordCredential(
        email: 'kari@example.com',
        password: 'secret-123',
      ),
    ).called(1);
    expect(changes, 1);
    expect(
      find.text('Password added. You can now sign in with email.'),
      findsOneWidget,
    );
    // The tile now offers the reset action.
    expect(find.text('Forgot Password'), findsOneWidget);
  });

  testWidgets('validates the length and the confirmation', (tester) async {
    useUser(signedInUser([providerInfo('facebook.com')]));
    await pumpSettingsWidget(tester, PasswordActionTile(authService: auth));

    await tester.tap(find.text('Add password'));
    await tester.pumpAndSettle();
    await tester.enterText(field('New password'), '12345');
    await tester.enterText(field('Confirm password'), '54321');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Use at least 6 characters.'), findsOneWidget);
    expect(find.text('The passwords do not match.'), findsOneWidget);
    verifyNever(
      () => auth.linkPasswordCredential(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('asks for an email when the account has none', (tester) async {
    useUser(signedInUser([providerInfo('facebook.com')], email: null));
    await pumpSettingsWidget(tester, PasswordActionTile(authService: auth));

    await tester.tap(find.text('Add password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
  });

  testWidgets('explains a failure and keeps the modal open', (tester) async {
    useUser(signedInUser([providerInfo('google.com')]));
    when(
      () => auth.linkPasswordCredential(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(FirebaseAuthException(code: 'requires-recent-login'));
    await pumpSettingsWidget(tester, PasswordActionTile(authService: auth));

    await tester.tap(find.text('Add password'));
    await tester.pumpAndSettle();
    await tester.enterText(field('New password'), 'secret-123');
    await tester.enterText(field('Confirm password'), 'secret-123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This action requires a recent sign-in. Please sign in again and retry.',
      ),
      findsOneWidget,
    );
    expect(field('New password'), findsOneWidget);
  });

  testWidgets('sends a reset email for a password account', (tester) async {
    useUser(signedInUser([providerInfo('password')]));
    when(() => auth.sendPasswordResetEmail(any())).thenAnswer((_) async {});
    await pumpSettingsWidget(tester, PasswordActionTile(authService: auth));

    expect(find.text('Add password'), findsNothing);
    await tester.tap(find.text('Forgot Password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();

    verify(() => auth.sendPasswordResetEmail('kari@example.com')).called(1);
    expect(
      find.text('Password reset email sent. Check your inbox.'),
      findsOneWidget,
    );
  });

  for (final (name, user) in [
    ('guests', () => signedInUser([], isAnonymous: true)),
    ('signed-out visitors', () => null),
  ]) {
    testWidgets('is hidden for $name', (tester) async {
      useUser(user());
      await pumpSettingsWidget(tester, PasswordActionTile(authService: auth));

      expect(find.text('Add password'), findsNothing);
      expect(find.text('Forgot Password'), findsNothing);
    });
  }
}
