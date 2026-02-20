import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import 'package:foodsavr/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class MockFacebookAuth extends Mock implements FacebookAuth {}

class MockLoginResult extends Mock implements LoginResult {}

class MockAccessToken extends Mock implements AccessToken {}

class FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockFacebookAuth mockFacebookAuth;
  late AuthService authService;
  late MockUserCredential mockUserCredential;

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
  });

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockFacebookAuth = MockFacebookAuth();
    mockUserCredential = MockUserCredential();
    authService = AuthService(
      mockFirebaseAuth,
      googleSignIn: mockGoogleSignIn,
      facebookAuth: mockFacebookAuth,
      supportsPersistence: true,
    );
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

    test('sendPasswordResetEmail calls FirebaseAuth', () async {
      when(
        () => mockFirebaseAuth.sendPasswordResetEmail(email: email),
      ).thenAnswer((_) async {});

      await authService.sendPasswordResetEmail(email);

      verify(
        () => mockFirebaseAuth.sendPasswordResetEmail(email: email),
      ).called(1);
    });

    test('signInWithGoogle signs in with Firebase credential', () async {
      final mockAccount = MockGoogleSignInAccount();
      final mockAuth = MockGoogleSignInAuthentication();

      when(
        () => mockGoogleSignIn.authenticate(),
      ).thenAnswer((_) async => mockAccount);
      when(() => mockAccount.authentication).thenReturn(mockAuth);
      when(() => mockAuth.idToken).thenReturn('id-token');
      when(
        () => mockFirebaseAuth.signInWithCredential(any()),
      ).thenAnswer((_) async => mockUserCredential);

      final result = await authService.signInWithGoogle();

      expect(result, mockUserCredential);
      verify(() => mockGoogleSignIn.authenticate()).called(1);
      verify(() => mockFirebaseAuth.signInWithCredential(any())).called(1);
    });

    test('signInWithFacebook signs in with Firebase credential', () async {
      final mockResult = MockLoginResult();
      final mockToken = MockAccessToken();

      when(() => mockFacebookAuth.login()).thenAnswer((_) async => mockResult);
      when(() => mockResult.accessToken).thenReturn(mockToken);
      when(() => mockToken.tokenString).thenReturn('token-string');
      when(
        () => mockFirebaseAuth.signInWithCredential(any()),
      ).thenAnswer((_) async => mockUserCredential);

      final result = await authService.signInWithFacebook();

      expect(result, mockUserCredential);
      verify(() => mockFacebookAuth.login()).called(1);
      verify(() => mockFirebaseAuth.signInWithCredential(any())).called(1);
    });

    test('signOut calls signOut', () async {
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

      await authService.signOut();

      verify(() => mockFirebaseAuth.signOut()).called(1);
    });
  });
}
