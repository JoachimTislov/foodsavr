import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/utils/sign_out_flow.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../support/localized_app.dart';

class _Auth extends Mock implements IAuthService {}

class _User extends Mock implements User {}

void main() {
  setUpAll(setUpLocalizedApp);

  late _Auth auth;

  setUp(() async {
    await getIt.reset();
    auth = _Auth();
    when(auth.signOut).thenAnswer((_) async {});
    getIt
      ..registerSingleton<Logger>(Logger(level: Level.off))
      ..registerSingleton<IAuthService>(auth);
  });

  tearDown(() => getIt.reset());

  Future<void> pump(WidgetTester tester) => pumpLocalized(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => SignOutFlow.run(context),
          child: const Text('go'),
        ),
      ),
    ),
  );

  testWidgets('signs out in one click', (tester) async {
    await pump(tester);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    verify(auth.signOut).called(1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a failed sign-out is reported', (tester) async {
    when(auth.signOut).thenAnswer((_) async => throw StateError('offline'));
    await pump(tester);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to sign out. Please try again.'), findsOneWidget);
  });

  testWidgets('a guest confirms before the account is deleted', (tester) async {
    final guest = _User();
    when(() => guest.isAnonymous).thenReturn(true);
    when(() => auth.currentUser).thenReturn(guest);
    await pump(tester);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of the guest account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(auth.signOut);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
    verify(auth.signOut).called(1);
  });
}
