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
      'authenticate calls signUp when isLogin is false and agreedToTerms is true',
      () async {
        const email = 'test@test.com';
        const password = 'password';
        authController.isLogin = false;
        authController.agreedToTerms = true;

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

    test(
      'authenticate sets error message when signUp called without agreedToTerms',
      () async {
        authController.isLogin = false;
        authController.agreedToTerms = false;

        await authController.authenticate(
          email: 'test@test.com',
          password: 'password',
        );

        expect(authController.errorMessage, 'auth.terms.required');
        verifyNever(
          () => mockAuthService.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
    );

    test('signInAsGuest calls auth service guest sign-in', () async {
      when(
        () => mockAuthService.signInAsGuest(),
      ).thenAnswer((_) async => mockUserCredential);

      await authController.signInAsGuest();

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
}
