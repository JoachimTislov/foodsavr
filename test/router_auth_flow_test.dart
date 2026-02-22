// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/router.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/auth_controller.dart';
import 'package:foodsavr/views/landing_page_view.dart';
import 'package:foodsavr/views/main_view.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUser extends Mock implements User {}

class _MockUserCredential extends Mock implements UserCredential {}

class _FakeAuthService extends IAuthService {
  final _userController = StreamController<User?>.broadcast();
  User? _currentUser;

  @override
  Stream<User?> get authStateChanges => _userController.stream;

  @override
  String? getUserId() {
    return _currentUser?.uid;
  }

  void _updateUser(User? user) {
    _currentUser = user;
    _userController.add(user);
  }

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final user = _MockUser();
    when(() => user.uid).thenReturn('test-uid');
    _updateUser(user);
    return _MockUserCredential();
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    final user = _MockUser();
    when(() => user.uid).thenReturn('test-uid');
    _updateUser(user);
    return _MockUserCredential();
  }

  @override
  Future<void> signOut() async {
    _updateUser(null);
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    final user = _MockUser();
    when(() => user.uid).thenReturn('test-uid');
    _updateUser(user);
    return _MockUserCredential();
  }

  @override
  Future<UserCredential> signInWithFacebook() async {
    final user = _MockUser();
    when(() => user.uid).thenReturn('test-uid');
    _updateUser(user);
    return _MockUserCredential();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  Future<void> dispose() async {
    await _userController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMessageHandler('flutter/lifecycle', (_) async => null);

  group('Auth routing regression', () {
    late _FakeAuthService authService;
    late GoRouter router;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await EasyLocalization.ensureInitialized();
      await getIt.reset();
      authService = _FakeAuthService();
      router = createAppRouter(authService);
      getIt.registerLazySingleton<IAuthService>(() => authService);
      getIt.registerFactory<AuthController>(
        () => AuthController(
          getIt<IAuthService>(),
          Logger(level: Level.off),
          (key) => key,
        ),
      );
    });

    tearDown(() async {
      router.dispose();
      await authService.dispose();
    });

    Widget createTestWidget({required GoRouter router}) {
      return EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: Builder(
          builder: (context) {
            return MaterialApp.router(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: router,
            );
          },
        ),
      );
    }

    testWidgets('should redirect to login when not authenticated', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(router: router));
      await tester.pumpAndSettle();
      expect(find.byType(LandingPageView), findsOneWidget);
    });

    testWidgets('should redirect to main when authenticated', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await authService.signIn(email: 'test@example.com', password: 'password');
      await tester.pumpWidget(createTestWidget(router: router));
      await tester.pumpAndSettle();
      // GoRouter might need extra pumps for the initial redirect if it happened during pumpWidget
      await tester.pumpAndSettle();
      expect(find.byType(MainAppScreen), findsOneWidget);
    });

    testWidgets('should handle session state change', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(router: router));
      await tester.pumpAndSettle();
      expect(find.byType(LandingPageView), findsOneWidget);

      // Sign in
      await authService.signIn(email: 'test@example.com', password: 'password');
      await tester.pump(); // Trigger stream listener
      await tester.pumpAndSettle(); // Allow redirect
      expect(find.byType(MainAppScreen), findsOneWidget);

      // Sign out
      await authService.signOut();
      await tester.pump(); // Trigger stream listener
      await tester.pumpAndSettle(); // Allow redirect
      expect(find.byType(LandingPageView), findsOneWidget);
    });
  });
}
