import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/public_routes.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/views/auth_view.dart';
import 'package:foodsavr/views/landing_page_view.dart';
import 'package:foodsavr/widgets/auth/auth_status_messages.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements IAuthService {}

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

void main() {
  late _MockAuthService authService;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableBuildModes = [];
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    // A translation future cached by an earlier test never completes here.
    rootBundle.clear();
    await getIt.reset();
    authService = _MockAuthService();
    when(() => authService.currentUser).thenReturn(null);
    when(
      () => authService.authStateChanges,
    ).thenAnswer((_) => const Stream.empty());
    getIt.registerFactory<UserController>(
      () => UserController(authService, Logger(level: Level.off)),
    );
  });

  tearDown(() => getIt.reset());

  Future<void> pumpView(WidgetTester tester, Widget view) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => view),
        for (final path in [
          '/dashboard',
          PublicRoutes.terms,
          PublicRoutes.privacy,
          PublicRoutes.deleteAccount,
        ])
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text('page $path')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp.router(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder notice(String action) => find.text(
    'By $action, you agree to our Terms of Service and Privacy Policy',
    findRichText: true,
  );

  void tapLink(WidgetTester tester, Finder text, String label) {
    TapGestureRecognizer? recognizer;
    tester.widget<RichText>(text).text.visitChildren((span) {
      if (span is TextSpan && span.text == label) {
        recognizer = span.recognizer as TapGestureRecognizer?;
      }
      return true;
    });
    recognizer!.onTap!();
  }

  final guestButton = find.text('Continue as guest');

  testWidgets('login shows the LettMat brand, guest access and notice', (
    tester,
  ) async {
    await pumpView(tester, const AuthView());

    expect(find.text('LettMat'), findsOneWidget);
    expect(find.byIcon(Icons.eco), findsOneWidget);
    expect(guestButton, findsOneWidget);
    expect(notice('signing in'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
    expect(find.text('Privacy Notice'), findsNothing);
    expect(find.text('Terms of Service'), findsNothing);
  });

  testWidgets('signup has only the implicit agreement notice', (tester) async {
    await pumpView(tester, const AuthView(isLogin: false));

    expect(find.text('LettMat'), findsOneWidget);
    expect(notice('creating an account'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(guestButton, findsNothing);
    expect(find.text('OR'), findsNothing);
    expect(find.text('Delete Account'), findsNothing);
    expect(find.text('Privacy Notice'), findsNothing);
    expect(find.text('Terms of Service'), findsNothing);
  });

  testWidgets('signup submits without ticking anything', (tester) async {
    when(
      () => authService.signUp(email: 'a@b.com', password: 'password123'),
    ).thenAnswer((_) async => _MockUserCredential());
    await pumpView(tester, const AuthView(isLogin: false));

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    verify(
      () => authService.signUp(email: 'a@b.com', password: 'password123'),
    ).called(1);
  });

  for (final (label, path) in [
    ('Terms of Service', PublicRoutes.terms),
    ('Privacy Policy', PublicRoutes.privacy),
  ]) {
    testWidgets('the $label link opens $path', (tester) async {
      await pumpView(tester, const AuthView(isLogin: false));

      tapLink(tester, notice('creating an account'), label);
      await tester.pumpAndSettle();

      expect(find.text('page $path'), findsOneWidget);
    });
  }

  testWidgets('guest sign-in leaves the auth screen', (tester) async {
    when(
      () => authService.signInAsGuest(),
    ).thenAnswer((_) async => _MockUserCredential());
    await pumpView(tester, const AuthView());

    await tester.tap(guestButton);
    await tester.pumpAndSettle();

    verify(() => authService.signInAsGuest()).called(1);
    expect(find.text('page /dashboard'), findsOneWidget);
  });

  for (final (button, serviceCall, message) in [
    (
      'Continue as guest',
      (_MockAuthService s) => s.signInAsGuest(),
      'Guest access is not available here yet. '
          'Create an account or sign in instead.',
    ),
    (
      'Continue with Google',
      (_MockAuthService s) => s.signInWithGoogle(),
      'Google sign-in is unavailable. You can sign in with email instead.',
    ),
    (
      'Continue with Facebook',
      (_MockAuthService s) => s.signInWithFacebook(),
      'Facebook sign-in is unavailable. You can sign in with email instead.',
    ),
  ]) {
    for (final (screen, view) in [
      ('login', const AuthView()),
      ('landing', const LandingPageView()),
    ]) {
      testWidgets('$screen: $button shows a disabled provider error', (
        tester,
      ) async {
        when(() => serviceCall(authService)).thenAnswer(
          (_) => Future.error(
            FirebaseAuthException(code: 'operation-not-allowed'),
          ),
        );
        await pumpView(tester, view);

        await tester.tap(find.text(button));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(AuthStatusMessages),
            matching: find.text(message),
          ),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    }
  }

  testWidgets('an existing guest is not offered guest access again', (
    tester,
  ) async {
    final guest = _MockUser();
    when(() => guest.isAnonymous).thenReturn(true);
    when(() => authService.currentUser).thenReturn(guest);

    await pumpView(tester, const AuthView());

    expect(guestButton, findsNothing);
  });

  testWidgets('hanging Facebook sign-in can be cancelled on AuthView', (
    tester,
  ) async {
    final completer = Completer<UserCredential>();
    when(
      () => authService.signInWithFacebook(),
    ).thenAnswer((_) => completer.future);
    await pumpView(tester, const AuthView());

    await tester.tap(find.text('Continue with Facebook'));
    await tester.pump();

    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(find.text('Cancel'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    completer.completeError(FirebaseAuthException(code: 'popup-timeout'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AuthStatusMessages),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets('deletion sign-in offers no guest access', (tester) async {
    await pumpView(tester, const AuthView(deletionOnly: true));

    expect(guestButton, findsNothing);
    expect(notice('signing in'), findsOneWidget);
  });
}
