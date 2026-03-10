import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/services/auth_controller.dart';
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
  late AuthController authController;
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
    when(
      () => mockCollectionService.getCollectionsForUser(any()),
    ).thenAnswer((_) async => []);
    when(
      () => mockCollectionService.addCollection(any()),
    ).thenAnswer((invocation) async => invocation.positionalArguments[0]);

    authController = AuthController(
      mockAuthService,
      mockCollectionService,
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
      verify(
        () => mockCollectionService.getCollectionsForUser('test-uid'),
      ).called(1);
      verify(() => mockCollectionService.addCollection(any())).called(2);
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
        verify(
          () => mockCollectionService.getCollectionsForUser('test-uid'),
        ).called(1);
        verify(() => mockCollectionService.addCollection(any())).called(2);
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
      verify(
        () => mockCollectionService.getCollectionsForUser('test-uid'),
      ).called(1);
      verify(() => mockCollectionService.addCollection(any())).called(2);
      expect(authController.isLoading, false);
      expect(authController.errorMessage, null);
    });
  });
}
