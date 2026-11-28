import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/widgets/settings/social_connections_section.dart';
import 'package:mocktail/mocktail.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthService auth;

  setUp(() async {
    await setUpSettingsWidgetTest();
    auth = MockAuthService();
    when(() => auth.linkGoogleProvider()).thenAnswer((_) async {});
    when(() => auth.linkFacebookProvider()).thenAnswer((_) async {});
  });

  void useUser(User? user) => when(() => auth.currentUser).thenReturn(user);

  Future<void> pumpSection(WidgetTester tester, {VoidCallback? onChanged}) =>
      pumpSettingsWidget(
        tester,
        SocialConnectionsSection(authService: auth, onChanged: onChanged),
      );

  testWidgets('shows a linked provider as connected with its email', (
    tester,
  ) async {
    useUser(
      signedInUser([providerInfo('google.com', email: 'kari@gmail.com')]),
    );
    await pumpSection(tester);

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('kari@gmail.com'), findsOneWidget);
    // Only Facebook can still be connected.
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Not linked to this account'), findsOneWidget);
  });

  testWidgets('connects a provider and updates its status', (tester) async {
    useUser(signedInUser([providerInfo('google.com')]));
    final linked = signedInUser([
      providerInfo('google.com'),
      providerInfo('facebook.com'),
    ]);
    when(
      () => auth.linkFacebookProvider(),
    ).thenAnswer((_) async => useUser(linked));
    var changes = 0;
    await pumpSection(tester, onChanged: () => changes++);

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    verify(() => auth.linkFacebookProvider()).called(1);
    verifyNever(() => auth.linkGoogleProvider());
    expect(changes, 1);
    expect(find.text('Connected'), findsNWidgets(2));
    expect(find.text('Connect'), findsNothing);
    expect(
      find.text('Facebook is now linked to your account.'),
      findsOneWidget,
    );
  });

  for (final (code, message) in [
    (
      'operation-not-allowed',
      'Google sign-in is unavailable. You can sign in with email instead.',
    ),
    (
      'credential-already-in-use',
      'This Google account already belongs to another user.',
    ),
    ('popup-closed-by-user', null),
    ('ERROR_ABORTED_BY_USER', null),
  ]) {
    testWidgets('handles $code when connecting', (tester) async {
      useUser(signedInUser([providerInfo('password')]));
      when(
        () => auth.linkGoogleProvider(),
      ).thenThrow(FirebaseAuthException(code: code));
      await pumpSection(tester);

      await tester.tap(find.text('Connect').first);
      await tester.pumpAndSettle();

      if (message == null) {
        expect(find.byType(SnackBar), findsNothing);
      } else {
        expect(find.text(message), findsOneWidget);
      }
      expect(find.text('Connect'), findsNWidgets(2));
    });
  }

  testWidgets('hanging Facebook link can be cancelled immediately', (
    tester,
  ) async {
    useUser(signedInUser([providerInfo('password')]));
    final completer = Completer<void>();
    when(() => auth.linkFacebookProvider()).thenAnswer((_) => completer.future);
    var changes = 0;
    await pumpSection(tester, onChanged: () => changes++);

    await tester.tap(find.text('Connect').last);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final cancelButton = find.byTooltip('Cancel');
    expect(cancelButton, findsOneWidget);

    await tester.tap(cancelButton);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Connect'), findsNWidgets(2));

    // Late error from the abandoned popup must not disrupt the UI.
    completer.completeError(FirebaseAuthException(code: 'popup-timeout'));
    await tester.pumpAndSettle();

    expect(changes, 0);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Connect'), findsNWidgets(2));
  });

  testWidgets('Facebook popup timeout clears busy state and shows error', (
    tester,
  ) async {
    useUser(signedInUser([providerInfo('password')]));
    when(
      () => auth.linkFacebookProvider(),
    ).thenThrow(FirebaseAuthException(code: 'popup-timeout'));
    await pumpSection(tester);

    await tester.tap(find.text('Connect').last);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Connect'), findsNWidgets(2));
    expect(
      find.text('Facebook sign-in failed. Try again or sign in with email.'),
      findsOneWidget,
    );
  });

  testWidgets('tells a guest that linking needs an account', (tester) async {
    useUser(signedInUser([], isAnonymous: true, email: null));
    await pumpSection(tester);

    expect(find.text('Guest session'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
