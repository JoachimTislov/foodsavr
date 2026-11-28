import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements IAuthService {}

class MockCollectionService extends Mock implements CollectionService {}

class MockLogger extends Mock implements Logger {}

class MockUser extends Mock implements User {}

class MockUserInfo extends Mock implements UserInfo {}

class MockUserCredential extends Mock implements UserCredential {}

class FakeCollection extends Fake implements Collection {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCollection());
  });

  late MockAuthService mockAuthService;
  late MockCollectionService mockCollectionService;
  late MockLogger mockLogger;
  late UserController authController;
  late MockUser mockUser;
  late MockUserCredential mockUserCredential;

  setUp(() {
    mockAuthService = MockAuthService();
    mockCollectionService = MockCollectionService();
    mockLogger = MockLogger();
    mockUser = MockUser();
    mockUserCredential = MockUserCredential();

    when(() => mockUser.uid).thenReturn('test-uid');
    when(() => mockUserCredential.user).thenReturn(mockUser);
    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    when(
      () => mockAuthService.authStateChanges,
    ).thenAnswer((_) => Stream<User?>.fromIterable([mockUser]));

    authController = UserController(
      mockAuthService,
      mockLogger,
      translate: (String key) => key,
    );
  });

  group('provider sign-in failures', () {
    final signIns =
        <String, (Future<UserCredential> Function(), Future<bool> Function())>{
          'google': (
            () => mockAuthService.signInWithGoogle(),
            () => authController.signInWithGoogle(),
          ),
          'facebook': (
            () => mockAuthService.signInWithFacebook(),
            () => authController.signInWithFacebook(),
          ),
          'guest': (
            () => mockAuthService.signInAsGuest(),
            () => authController.signInAsGuest(),
          ),
        };

    Future<void> expectError(
      String provider,
      Object error,
      String? expected,
    ) async {
      final (serviceCall, signIn) = signIns[provider]!;
      when(serviceCall).thenAnswer((_) => Future.error(error));

      expect(await signIn(), isFalse, reason: '$provider $error');

      expect(authController.errorMessage, expected, reason: '$provider $error');
      expect(authController.isLoading, isFalse);
    }

    for (final provider in ['google', 'facebook', 'guest']) {
      test('$provider setup errors say it is unavailable', () async {
        for (final code in [
          'operation-not-allowed',
          'admin-restricted-operation',
          'unauthorized-domain',
          'invalid-oauth-client-id',
          'invalid-api-key',
          'api-key-not-valid.-please-pass-a-valid-api-key.',
          'invalid-app-id',
          'app-not-authorized',
          'auth-domain-config-required',
          'configuration-not-found',
          'operation-not-supported-in-this-environment',
          'google-sdk-unavailable',
          'facebook-sdk-unavailable',
        ]) {
          await expectError(
            provider,
            FirebaseAuthException(code: code),
            'auth.error.${provider}_unavailable',
          );
        }
      });

      test('$provider unexpected errors never expose raw details', () async {
        for (final error in [
          FirebaseAuthException(code: 'internal-error', message: 'secret'),
          Exception('secret'),
          StateError('secret'),
        ]) {
          await expectError(provider, error, 'auth.error.${provider}_failed');
        }
      });

      test('$provider cancellation stays silent', () async {
        for (final code in [
          'ERROR_ABORTED_BY_USER',
          'popup-closed-by-user',
          'cancelled-popup-request',
          'web-context-canceled',
        ]) {
          await expectError(provider, FirebaseAuthException(code: code), null);
        }
      });
    }

    test('actionable errors have their own message', () async {
      for (final MapEntry(:key, :value) in {
        'popup-blocked': 'auth.error.popup_blocked',
        'web-storage-unsupported': 'auth.error.web_storage_unsupported',
        'network-request-failed': 'auth.error.network',
        'account-exists-with-different-credential': 'auth.error.account_exists',
        'user-disabled': 'auth.error.user_disabled',
      }.entries) {
        await expectError('google', FirebaseAuthException(code: key), value);
      }
    });

    test('a retry clears the previous error', () async {
      await expectError(
        'guest',
        Exception('offline'),
        'auth.error.guest_failed',
      );
      when(
        () => mockAuthService.signInAsGuest(),
      ).thenAnswer((_) async => mockUserCredential);

      expect(await authController.signInAsGuest(), isTrue);

      expect(authController.errorMessage, isNull);
    });
  });

  group('AuthController', () {
    test(
      'Facebook provider misconfiguration sets an actionable error',
      () async {
        when(
          () => mockAuthService.signInWithFacebook(),
        ).thenThrow(FirebaseAuthException(code: 'operation-not-allowed'));

        await authController.signInWithFacebook();

        expect(authController.errorMessage, 'auth.error.facebook_unavailable');
        expect(authController.isLoading, false);
      },
    );

    test('initial state is correct', () {
      expect(authController.isLogin, true);
      expect(authController.isLoading, false);
      expect(authController.errorMessage, null);
      expect(authController.successMessage, null);
    });

    test('isLogin toggle clears messages', () {
      authController.isLogin = false;
      expect(authController.isLogin, false);
      expect(authController.errorMessage, null);
    });

    test('authenticate calls signIn when isLogin is true', () async {
      const email = 'test@test.com';
      const password = 'password';

      when(
        () => mockAuthService.signIn(
          email: email,
          password: password,
          rememberMe: any(named: 'rememberMe'),
        ),
      ).thenAnswer((_) async => mockUserCredential);

      await authController.authenticate(email: email, password: password);

      verify(
        () => mockAuthService.signIn(
          email: email,
          password: password,
          rememberMe: false,
        ),
      ).called(1);
      verifyNever(
        () => mockCollectionService.getCollectionsForUser('test-uid'),
      );
      verifyNever(() => mockCollectionService.addCollection(any()));
      expect(authController.isLoading, false);
    });

    test(
      'authenticate calls signUp without a separate terms agreement',
      () async {
        const email = 'test@test.com';
        const password = 'password';
        authController.isLogin = false;

        when(
          () => mockAuthService.signUp(email: email, password: password),
        ).thenAnswer((_) async => mockUserCredential);

        await authController.authenticate(email: email, password: password);

        verify(
          () => mockAuthService.signUp(email: email, password: password),
        ).called(1);
        verifyNever(
          () => mockCollectionService.getCollectionsForUser('test-uid'),
        );
        verifyNever(() => mockCollectionService.addCollection(any()));
      },
    );

    test('signInAsGuest calls auth service guest sign-in', () async {
      when(
        () => mockAuthService.signInAsGuest(),
      ).thenAnswer((_) async => mockUserCredential);

      expect(await authController.signInAsGuest(), isTrue);

      verify(() => mockAuthService.signInAsGuest()).called(1);
      verifyNever(
        () => mockCollectionService.getCollectionsForUser('test-uid'),
      );
      verifyNever(() => mockCollectionService.addCollection(any()));
      expect(authController.isLoading, false);
      expect(authController.errorMessage, null);
    });

    test('changeEmail sets success message on success', () async {
      when(
        () => mockAuthService.changeEmail(
          currentPassword: 'password',
          newEmail: 'new@test.com',
        ),
      ).thenAnswer((_) async {});

      await authController.changeEmail(
        currentPassword: 'password',
        newEmail: 'new@test.com',
      );

      verify(
        () => mockAuthService.changeEmail(
          currentPassword: 'password',
          newEmail: 'new@test.com',
        ),
      ).called(1);
      expect(authController.successMessage, 'profile.change_email_sent');
      expect(authController.errorMessage, null);
      expect(authController.isLoading, false);
    });

    test('changeEmail rejects empty email without calling service', () async {
      await authController.changeEmail(
        currentPassword: 'password',
        newEmail: '   ',
      );

      verifyNever(
        () => mockAuthService.changeEmail(
          currentPassword: any(named: 'currentPassword'),
          newEmail: any(named: 'newEmail'),
        ),
      );
      expect(authController.errorMessage, 'profile.new_email_prompt');
    });

    test('changeEmail sets error message on failure', () async {
      when(
        () => mockAuthService.changeEmail(
          currentPassword: 'password',
          newEmail: 'new@test.com',
        ),
      ).thenThrow(Exception('reauth failed'));

      await authController.changeEmail(
        currentPassword: 'password',
        newEmail: 'new@test.com',
      );

      expect(authController.errorMessage, isNotNull);
      expect(authController.successMessage, null);
      expect(authController.isLoading, false);
    });

    test('forgotPassword sets success message on success', () async {
      when(
        () => mockAuthService.sendPasswordResetEmail('test@test.com'),
      ).thenAnswer((_) async {});

      await authController.forgotPassword('test@test.com');

      expect(authController.successMessage, 'auth.reset.email_sent');
      expect(authController.errorMessage, null);
    });
  });

  test('deletion asks for a password linked without an auth event', () {
    final linked = MockUser();
    final password = MockUserInfo();
    when(() => password.providerId).thenReturn('password');
    when(() => mockUser.providerData).thenReturn([]);
    when(() => linked.providerData).thenReturn([password]);
    expect(authController.deletionRequiresPassword, isFalse);

    when(() => mockAuthService.currentUser).thenReturn(linked);

    expect(authController.deletionRequiresPassword, isTrue);
  });
}
