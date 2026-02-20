import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/services/auth_controller.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements IAuthService {}

class MockLogger extends Mock implements Logger {}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  late MockAuthService mockAuthService;
  late MockLogger mockLogger;
  late AuthController authController;

  setUp(() {
    mockAuthService = MockAuthService();
    mockLogger = MockLogger();
    authController = AuthController(mockAuthService, mockLogger);
  });

  group('AuthController', () {
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
      ).thenAnswer((_) async => MockUserCredential());

      await authController.authenticate(email: email, password: password);

      verify(
        () => mockAuthService.signIn(
          email: email,
          password: password,
          rememberMe: false,
        ),
      ).called(1);
      expect(authController.isLoading, false);
    });

    test(
      'authenticate calls signUp when isLogin is false and agreedToTerms is true',
      () async {
        const email = 'test@test.com';
        const password = 'password';
        authController.isLogin = false;
        authController.agreedToTerms = true;

        when(
          () => mockAuthService.signUp(email: email, password: password),
        ).thenAnswer((_) async => MockUserCredential());

        await authController.authenticate(email: email, password: password);

        verify(
          () => mockAuthService.signUp(email: email, password: password),
        ).called(1);
      },
    );

    // test(
    //   'authenticate sets error message when signUp called without agreedToTerms',
    //   () async {
    //     authController.isLogin = false;
    //     authController.agreedToTerms = false;
    //
    //     await authController.authenticate(
    //       email: 'test@test.com',
    //       password: 'password',
    //     );
    //
    //     expect(authController.errorMessage, 'auth_terms_required'.tr());
    //     verifyNever(
    //       () => mockAuthService.signUp(
    //         email: any(named: 'email'),
    //         password: any(named: 'password'),
    //       ),
    //     );
    //   },
    // );
  });
}
