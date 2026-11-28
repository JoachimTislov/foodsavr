import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart';
import 'package:foodsavr/interfaces/i_error_reporter.dart';
import 'package:foodsavr/interfaces/i_account_data_repository.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/validation/validators/collection_model_validator.dart';
import 'package:foodsavr/services/firebase_auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAccountDataRepository dataRepository;
  late MockSecureStorage secureStorage;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockFacebookAuth mockFacebookAuth;
  late AuthService authService;
  late MockUserCredential mockUserCredential;
  late MockLogger mockLogger;
  late MockErrorReporter errorReporter;

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
    registerFallbackValue(Uri());
    registerFallbackValue(GoogleAuthProvider());
  });

  setUp(() {
    dataRepository = MockAccountDataRepository();
    when(() => dataRepository.deleteForUser(any())).thenAnswer((_) async {});
    secureStorage = MockSecureStorage();
    when(() => secureStorage.clearStoreTokens()).thenAnswer((_) async {});
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockFacebookAuth = MockFacebookAuth();
    mockUserCredential = MockUserCredential();
    mockLogger = MockLogger();
    errorReporter = MockErrorReporter();
    when(
      () => errorReporter.recordError(any(), any(), reason: 'Facebook sign-in'),
    ).thenAnswer((_) async {});
    when(() => mockGoogleSignIn.initialize()).thenAnswer((_) async {});
    authService = AuthService(
      mockFirebaseAuth,
      googleSignIn: mockGoogleSignIn,
      facebookAuth: mockFacebookAuth,
      supportsPersistence: true,
      isWeb: false,
      accountDataRepository: dataRepository,
      secureStorage: secureStorage,
      logger: mockLogger,
      errorReporter: errorReporter,
    );
  });

  group('AuthService on web', () {
    late AuthService webAuthService;

    setUp(() {
      webAuthService = AuthService(
        mockFirebaseAuth,
        googleSignIn: mockGoogleSignIn,
        facebookAuth: mockFacebookAuth,
        supportsPersistence: true,
        isWeb: true,
        accountDataRepository: dataRepository,
        secureStorage: secureStorage,
        logger: mockLogger,
        errorReporter: errorReporter,
      );
      when(
        () => mockFirebaseAuth.signInWithPopup(any()),
      ).thenAnswer((_) async => mockUserCredential);
    });

    test('signInWithGoogle uses the Firebase popup', () async {
      final result = await webAuthService.signInWithGoogle();

      expect(result, mockUserCredential);
      final provider =
          verify(
                () => mockFirebaseAuth.signInWithPopup(captureAny()),
              ).captured.single
              as AuthProvider;
      expect(provider.providerId, GoogleAuthProvider.PROVIDER_ID);
      verifyNever(() => mockGoogleSignIn.initialize());
      verifyNever(() => mockGoogleSignIn.authenticate());
    });

    test('signInWithFacebook uses the Firebase popup', () async {
      final result = await webAuthService.signInWithFacebook();

      expect(result, mockUserCredential);
      final provider =
          verify(
                () => mockFirebaseAuth.signInWithPopup(captureAny()),
              ).captured.single
              as AuthProvider;
      expect(provider.providerId, FacebookAuthProvider.PROVIDER_ID);
      verifyNever(() => mockFacebookAuth.login());
    });

    test(
      'Facebook reports a disabled web provider without OAuth details',
      () async {
        when(() => mockFirebaseAuth.signInWithPopup(any())).thenThrow(
          FirebaseAuthException(
            code: 'operation-not-allowed',
            message: 'sensitive provider response',
          ),
        );

        await expectLater(
          webAuthService.signInWithFacebook(),
          throwsA(isA<FirebaseAuthException>()),
        );

        final report = verify(
          () => errorReporter.recordError(
            captureAny(),
            any(),
            reason: 'Facebook sign-in',
          ),
        ).captured.single;
        expect(report.toString(), contains('operation-not-allowed'));
        expect(
          report.toString(),
          isNot(contains('sensitive provider response')),
        );
        verifyNever(() => mockFacebookAuth.login());
      },
    );

    test('closing the popup maps to an aborted sign-in', () async {
      when(
        () => mockFirebaseAuth.signInWithPopup(any()),
      ).thenThrow(FirebaseAuthException(code: 'popup-closed-by-user'));

      expect(
        () => webAuthService.signInWithGoogle(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'ERROR_ABORTED_BY_USER',
          ),
        ),
      );
    });
  });

  group('default provisioning', () {
    const uid = 'test-user';
    const email = 'test@example.com';
    const password = 'password123';
    late MockCollectionRepository repository;
    late CollectionService collections;

    setUp(() {
      repository = MockCollectionRepository();
      when(() => repository.getCollections(uid)).thenAnswer((_) async => []);
      collections = CollectionService(
        repository,
        CollectionModelValidator(),
        mockLogger,
      );
      final user = MockUser();
      when(() => user.uid).thenReturn(uid);
      when(() => user.isAnonymous).thenReturn(true);
      when(() => mockUserCredential.user).thenReturn(user);
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(
        () => mockFirebaseAuth.setPersistence(Persistence.SESSION),
      ).thenAnswer((_) async {});
      when(
        () => mockFirebaseAuth.signInAnonymously(),
      ).thenAnswer((_) async => mockUserCredential);
      when(
        () => user.linkWithCredential(any()),
      ).thenAnswer((_) async => mockUserCredential);
      when(
        () => mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ).thenAnswer((_) async => mockUserCredential);
      when(
        () => mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ).thenAnswer((_) async => mockUserCredential);
    });

    for (final method in ['sign-up', 'sign-in', 'guest', 'guest-to-email']) {
      test('$method creates no inventory or shopping list', () async {
        if (method == 'sign-up') {
          when(() => mockFirebaseAuth.currentUser).thenReturn(null);
        }
        final signIn = switch (method) {
          'sign-in' => () => authService.signIn(
            email: email,
            password: password,
          ),
          'guest' => authService.signInAsGuest,
          _ => () => authService.signUp(email: email, password: password),
        };

        expect(await signIn(), mockUserCredential);

        expect(await collections.getCollectionsForUser(uid), isEmpty);
        // The only repository call is the read above.
        verify(() => repository.getCollections(uid)).called(1);
        verifyNoMoreInteractions(repository);
        verifyZeroInteractions(dataRepository);
      });
    }
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
      const uid = 'some-uid';
      final mockUser = MockUser();
      when(() => mockUser.uid).thenReturn(uid);
      when(() => mockUserCredential.user).thenReturn(mockUser);
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);
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

    test('signUp links credentials when current user is anonymous', () async {
      final mockUser = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.isAnonymous).thenReturn(true);
      when(
        () => mockUser.linkWithCredential(any()),
      ).thenAnswer((_) async => mockUserCredential);

      final result = await authService.signUp(email: email, password: password);

      expect(result, mockUserCredential);
      verify(() => mockUser.linkWithCredential(any())).called(1);
      verifyNever(
        () => mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );
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
      when(
        () => mockFirebaseAuth.signInWithCredential(any()),
      ).thenAnswer((_) async => mockUserCredential);

      final result = await authService.signInWithGoogle();

      expect(result, mockUserCredential);
      verifyInOrder([
        () => mockGoogleSignIn.initialize(),
        () => mockGoogleSignIn.authenticate(),
      ]);
      verify(() => mockFirebaseAuth.signInWithCredential(any())).called(1);
    });

    test('signInWithGoogle retries initialization after a failure', () async {
      final mockAccount = MockGoogleSignInAccount();
      final mockAuth = MockGoogleSignInAuthentication();
      var calls = 0;
      when(() => mockGoogleSignIn.initialize()).thenAnswer((_) async {
        if (calls++ == 0) throw Exception('init failed');
      });
      when(
        () => mockGoogleSignIn.authenticate(),
      ).thenAnswer((_) async => mockAccount);
      when(() => mockAccount.authentication).thenReturn(mockAuth);
      when(
        () => mockFirebaseAuth.signInWithCredential(any()),
      ).thenAnswer((_) async => mockUserCredential);

      await expectLater(authService.signInWithGoogle(), throwsException);
      expect(await authService.signInWithGoogle(), mockUserCredential);
      verify(() => mockGoogleSignIn.initialize()).called(2);
    });

    test('signInWithGoogle throws a clear error when canceled', () async {
      when(() => mockGoogleSignIn.authenticate()).thenThrow(
        GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'The user canceled the sign-in flow.',
        ),
      );

      await expectLater(
        () => authService.signInWithGoogle(),
        throwsA(isA<FirebaseAuthException>()),
      );

      verifyNever(() => mockFirebaseAuth.signInWithCredential(any()));
    });

    for (final code in [
      GoogleSignInExceptionCode.clientConfigurationError,
      GoogleSignInExceptionCode.providerConfigurationError,
    ]) {
      test('signInWithGoogle reports ${code.name} as unavailable', () async {
        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenThrow(GoogleSignInException(code: code));

        await expectLater(
          authService.signInWithGoogle(),
          throwsAuthCode('google-sdk-unavailable'),
        );
        verifyNever(() => mockFirebaseAuth.signInWithCredential(any()));
      });
    }

    for (final error in <Object>[
      MissingPluginException(),
      UnimplementedError(),
    ]) {
      test(
        'signInWithGoogle reports ${error.runtimeType} as unavailable',
        () async {
          when(
            () => mockGoogleSignIn.initialize(),
          ).thenAnswer((_) => Future.error(error));

          await expectLater(
            authService.signInWithGoogle(),
            throwsAuthCode('google-sdk-unavailable'),
          );
          verifyNever(() => mockGoogleSignIn.authenticate());
        },
      );
    }

    test('signInWithGoogle requires an ID token', () async {
      final account = MockGoogleSignInAccount();
      when(
        () => mockGoogleSignIn.authenticate(),
      ).thenAnswer((_) async => account);
      when(
        () => account.authentication,
      ).thenReturn(const GoogleSignInAuthentication(idToken: null));

      await expectLater(
        authService.signInWithGoogle(),
        throwsAuthCode('google-sdk-unavailable'),
      );
      verifyNever(() => mockFirebaseAuth.signInWithCredential(any()));
    });

    test('signInWithGoogle keeps other SDK failures', () async {
      const failure = GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
      );
      when(() => mockGoogleSignIn.authenticate()).thenThrow(failure);

      await expectLater(authService.signInWithGoogle(), throwsA(same(failure)));
    });

    test('signInAsGuest propagates disabled anonymous sign-in', () async {
      when(
        () => mockFirebaseAuth.signInAnonymously(),
      ).thenThrow(FirebaseAuthException(code: 'admin-restricted-operation'));

      await expectLater(
        authService.signInAsGuest(),
        throwsAuthCode('admin-restricted-operation'),
      );
    });

    test('signInWithFacebook signs in with Firebase credential', () async {
      final mockResult = MockLoginResult();
      final mockToken = MockAccessToken();

      when(() => mockFacebookAuth.login()).thenAnswer((_) async => mockResult);
      when(() => mockResult.status).thenReturn(LoginStatus.success);
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

    test('Facebook SDK failure is distinct from cancellation', () async {
      when(
        () => mockFacebookAuth.login(),
      ).thenAnswer((_) async => LoginResult(status: LoginStatus.failed));

      await expectLater(
        authService.signInWithFacebook(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'facebook-sdk-failed',
          ),
        ),
      );
      verifyNever(() => mockFirebaseAuth.signInWithCredential(any()));
    });

    test(
      'Facebook SDK unavailable after native registration failure',
      () async {
        when(
          () => mockFacebookAuth.login(),
        ).thenThrow(MissingPluginException());

        await expectLater(
          authService.signInWithFacebook(),
          throwsA(
            isA<FirebaseAuthException>().having(
              (e) => e.code,
              'code',
              'facebook-sdk-unavailable',
            ),
          ),
        );
        verify(
          () => errorReporter.recordError(
            any(),
            any(),
            reason: 'Facebook sign-in',
          ),
        ).called(1);
        verifyNever(() => mockFirebaseAuth.signInWithCredential(any()));
      },
    );

    test('signInWithFacebook throws when the user cancels', () async {
      when(
        () => mockFacebookAuth.login(),
      ).thenAnswer((_) async => LoginResult(status: LoginStatus.cancelled));

      await expectLater(
        authService.signInWithFacebook(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'ERROR_ABORTED_BY_USER',
          ),
        ),
      );

      verify(() => mockFacebookAuth.login()).called(1);
      verifyNever(() => mockFirebaseAuth.signInWithCredential(any()));
      verifyZeroInteractions(errorReporter);
    });

    test(
      'guest deletion commits data cleanup before deleting the Auth user',
      () async {
        final user = MockUser();
        when(() => mockFirebaseAuth.currentUser).thenReturn(user);
        when(() => user.isAnonymous).thenReturn(true);
        when(() => user.uid).thenReturn('some-uid');
        when(() => user.delete()).thenAnswer((_) async {});
        await authService.deleteAccount();
        verifyInOrder([
          () => dataRepository.deleteForUser('some-uid'),
          () => user.delete(),
          () => secureStorage.clearStoreTokens(),
        ]);
      },
    );

    test(
      'deletion keeps the Auth account and local tokens when cleanup fails',
      () async {
        final user = MockUser();
        when(() => mockFirebaseAuth.currentUser).thenReturn(user);
        when(() => user.isAnonymous).thenReturn(true);
        when(() => user.uid).thenReturn('some-uid');
        final denied = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
        when(() => dataRepository.deleteForUser('some-uid')).thenThrow(denied);

        await expectLater(authService.deleteAccount(), throwsA(same(denied)));
        verifyNever(() => user.delete());
        verifyZeroInteractions(secureStorage);
      },
    );

    test('account verification must succeed before deletion starts', () async {
      final user = MockUser();
      final passwordProvider = MockUserInfo();
      when(() => passwordProvider.providerId).thenReturn('password');
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.uid).thenReturn('some-uid');
      when(() => user.email).thenReturn('user@example.com');
      when(() => user.providerData).thenReturn([passwordProvider]);
      when(() => user.delete()).thenAnswer((_) async {});

      await expectLater(
        authService.deleteAccount(),
        throwsA(
          isA<FirebaseAuthException>().having(
            (e) => e.code,
            'code',
            'requires-recent-login',
          ),
        ),
      );
      final rejected = FirebaseAuthException(code: 'wrong-password');
      when(() => user.reauthenticateWithCredential(any())).thenThrow(rejected);
      await expectLater(
        authService.deleteAccount(reauthenticate: true, password: 'wrong'),
        throwsA(same(rejected)),
      );
      verifyZeroInteractions(dataRepository);
      verifyZeroInteractions(secureStorage);
      verifyNever(() => user.delete());

      when(
        () => user.reauthenticateWithCredential(any()),
      ).thenAnswer((_) async => mockUserCredential);
      await authService.deleteAccount(
        reauthenticate: true,
        password: 'password',
      );

      verifyInOrder([
        () => user.reauthenticateWithCredential(any()),
        () => dataRepository.deleteForUser('some-uid'),
        () => user.delete(),
        () => secureStorage.clearStoreTokens(),
      ]);
    });

    test('deleteAccount with no current user does nothing', () async {
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);
      await authService.deleteAccount();
      verifyNever(() => mockFirebaseAuth.signOut());
    });
    test('signOut calls signOut', () async {
      final mockUser = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.isAnonymous).thenReturn(false);
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

      await authService.signOut();

      verify(() => mockFirebaseAuth.signOut()).called(1);
    });

    test('signInAsGuest calls signInAnonymously', () async {
      when(
        () => mockFirebaseAuth.signInAnonymously(),
      ).thenAnswer((_) async => mockUserCredential);

      final result = await authService.signInAsGuest();

      expect(result, mockUserCredential);
      verify(() => mockFirebaseAuth.signInAnonymously()).called(1);
    });
  });
}

Matcher throwsAuthCode(String code) =>
    throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', code));

class FakeAuthCredential extends Fake implements AuthCredential {}

class MockAccessToken extends Mock implements AccessToken {}

class MockFacebookAuth extends Mock implements FacebookAuth {}

class MockAccountDataRepository extends Mock
    implements IAccountDataRepository {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockUserInfo extends Mock implements UserInfo {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

/// Overrides [idToken] with a plain getter instead of a `when()` stub:
/// stubbing a real (non-Mock) getter inside `when()` throws
/// "No method stub was called".
class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {
  @override
  String? get idToken => 'id-token';
}

class MockLoginResult extends Mock implements LoginResult {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

class MockLogger extends Mock implements Logger {}

class MockCollectionRepository extends Mock implements ICollectionRepository {}

class MockErrorReporter extends Mock implements IErrorReporter {}
