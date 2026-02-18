import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:foodsavr/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late AuthService authService;
  late MockUserCredential mockUserCredential;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockUserCredential = MockUserCredential();
    authService = AuthService(mockFirebaseAuth);
  });

  group('AuthService', () {
    const email = 'test@example.com';
    const password = 'password123';

    test(
      'signIn with rememberMe=false (default) sets Persistence.SESSION',
      () async {
        when(
          () => mockFirebaseAuth.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
        ).thenAnswer((_) async => mockUserCredential);

        when(
          () => mockFirebaseAuth.setPersistence(Persistence.SESSION),
        ).thenAnswer((_) async {});

        await authService.signIn(email: email, password: password);

        verify(
          () => mockFirebaseAuth.setPersistence(Persistence.SESSION),
        ).called(1);
        verify(
          () => mockFirebaseAuth.signInWithEmailAndPassword(
            email: email,
            password: password,
          ),
        ).called(1);
      },
    );

    test('signIn with rememberMe=true sets Persistence.LOCAL', () async {
      when(
        () => mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ).thenAnswer((_) async => mockUserCredential);

      when(
        () => mockFirebaseAuth.setPersistence(Persistence.LOCAL),
      ).thenAnswer((_) async {});

      await authService.signIn(
        email: email,
        password: password,
        rememberMe: true,
      );

      verify(
        () => mockFirebaseAuth.setPersistence(Persistence.LOCAL),
      ).called(1);
      verify(
        () => mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ).called(1);
    });

    test('signUp calls createUserWithEmailAndPassword', () async {
      when(
        () => mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ).thenAnswer((_) async => mockUserCredential);

      final result = await authService.signUp(email: email, password: password);

      expect(result, mockUserCredential);
      verify(
        () => mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ).called(1);
    });

    test('signOut calls signOut', () async {
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

      await authService.signOut();

      verify(() => mockFirebaseAuth.signOut()).called(1);
    });
  });
}
