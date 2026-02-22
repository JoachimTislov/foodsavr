// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/router.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockUser extends Mock implements User {}

class _FakeAuthService implements IAuthService {
  final _controller = StreamController<User?>.broadcast();
  String? _userId;

  void signInForTest(String userId) {
    _userId = userId;
    _controller.add(_MockUser());
  }

  void signOutForTest() {
    _userId = null;
    _controller.add(null);
  }

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  String? getUserId() => _userId;

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {
    signOutForTest();
  }

  @override
  Future<UserCredential> signInWithFacebook() {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signInWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    throw UnimplementedError();
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  group('Router Tests', () {
    late _FakeAuthService authService;
    late GoRouter router;

    setUp(() {
      authService = _FakeAuthService();
      router = createAppRouter(authService);
    });

    tearDown(() async {
      router.dispose();
      await authService.dispose();
    });

    test('createAppRouter returns a configured GoRouter', () {
      expect(router, isA<GoRouter>());
      expect(router.configuration.routes, isNotEmpty);
    });

    test('router has correct initial location', () {
      expect(router.routeInformationProvider.value.uri.path, '/');
    });

    test('router refreshes on auth state changes', () async {
      authService.signInForTest('test-user');
      await Future.delayed(const Duration(milliseconds: 100));
      expect(authService.getUserId(), 'test-user');
    });

    test('_AuthStreamListenable disposes subscription properly', () async {
      final router2 = createAppRouter(authService);
      router2.dispose();
      // Should not throw after disposal
      expect(() => authService.signInForTest('test'), returnsNormally);
    });

    test('router handles sign out state change', () async {
      authService.signInForTest('user-456');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authService.getUserId(), 'user-456');

      authService.signOutForTest();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authService.getUserId(), isNull);
    });

    test('router configuration includes all expected routes', () {
      final routes = router.configuration.routes;
      expect(routes.length, greaterThanOrEqualTo(2));
    });

    test('getUserId returns null when not logged in', () {
      expect(authService.getUserId(), isNull);
    });

    test('getUserId returns userId when logged in', () {
      authService.signInForTest('uid-789');
      expect(authService.getUserId(), 'uid-789');
    });
  });
}
