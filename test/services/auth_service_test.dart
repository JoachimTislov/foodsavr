import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_collection_repository.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/validation/validators/collection_model_validator.dart';
import 'package:foodsavr/services/firebase_auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockFacebookAuth mockFacebookAuth;
  late AuthService authService;
  late MockUserCredential mockUserCredential;
  late MockCollectionService mockCollectionService;
  late MockLogger mockLogger;

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
    registerFallbackValue(Uri());
    registerFallbackValue(GoogleAuthProvider());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockFacebookAuth = MockFacebookAuth();
    mockUserCredential = MockUserCredential();
    mockCollectionService = MockCollectionService();
    mockLogger = MockLogger();
    when(() => mockGoogleSignIn.initialize()).thenAnswer((_) async {});
    authService = AuthService(
      mockFirebaseAuth,
      googleSignIn: mockGoogleSignIn,
      facebookAuth: mockFacebookAuth,
      supportsPersistence: true,
      isWeb: false,
      firestore: mockFirestore,
      collectionService: mockCollectionService,
      logger: mockLogger,
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
        firestore: mockFirestore,
        collectionService: mockCollectionService,
        logger: mockLogger,
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

  group('initial collections', () {
    const uid = 'test-user';
    const email = 'test@example.com';
    const password = 'password123';
    late CollectionService collections;
    late AuthService service;
    late Map<String, Collection> stored;

    setUp(() {
      final repository = MockCollectionRepository();
      stored = {};
      when(
        () => repository.getCollections(
          uid,
          serverOnly: any(named: 'serverOnly'),
        ),
      ).thenAnswer((_) async => stored.values.toList());
      when(() => repository.addCollectionsInBatch(any())).thenAnswer((
        call,
      ) async {
        final batch = call.positionalArguments.single as List<Collection>;
        for (final collection in batch) {
          stored[collection.id] = collection;
        }
      });
      collections = CollectionService(
        repository,
        CollectionModelValidator(),
        mockLogger,
      );
      service = AuthService(
        mockFirebaseAuth,
        googleSignIn: mockGoogleSignIn,
        facebookAuth: mockFacebookAuth,
        supportsPersistence: false,
        isWeb: true,
        firestore: mockFirestore,
        collectionService: collections,
        logger: mockLogger,
      );
      final user = MockUser();
      when(() => user.uid).thenReturn(uid);
      when(() => user.isAnonymous).thenReturn(true);
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(() => mockUserCredential.user).thenReturn(user);
      when(
        () => mockFirebaseAuth.signInWithPopup(any()),
      ).thenAnswer((_) async => mockUserCredential);
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
    });

    Future<void> loadNorwegian(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('nb')],
          startLocale: const Locale('nb'),
          path: 'assets/translations',
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final provider in ['Google', 'Facebook', 'guest', 'guest-to-email']) {
      testWidgets(
        '$provider provisions one Norwegian inventory and shopping list',
        (tester) async {
          await loadNorwegian(tester);
          final signIn = switch (provider) {
            'Google' => service.signInWithGoogle,
            'Facebook' => service.signInWithFacebook,
            'guest' => service.signInAsGuest,
            _ => () => service.signUp(email: email, password: password),
          };
          Future<void> expectDefaults() async {
            final result = await collections.getCollectionsForUser(uid);
            expect(
              result.map((collection) => (collection.type, collection.name)),
              unorderedEquals([
                (CollectionType.inventory, 'Beholdning'),
                (CollectionType.shoppingList, 'Handleliste'),
              ]),
            );
          }

          await signIn();
          await expectDefaults();
          await (provider == 'guest-to-email'
              ? service.signIn(email: email, password: password)
              : signIn());
          await expectDefaults();
        },
      );
    }

    testWidgets('fills a missing type and preserves the existing inventory', (
      tester,
    ) async {
      await loadNorwegian(tester);
      const inventory = Collection(
        id: 'custom',
        userId: uid,
        name: 'Pantry',
        type: CollectionType.inventory,
        productIds: ['rice'],
      );
      stored[inventory.id] = inventory;

      await service.signUp(email: email, password: password);

      final result = await collections.getCollectionsForUser(uid);
      expect(result, hasLength(2));
      expect(
        result.singleWhere((c) => c.type == CollectionType.inventory),
        inventory,
      );
      expect(
        result.singleWhere((c) => c.type == CollectionType.shoppingList).name,
        'Handleliste',
      );
    });
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
      when(
        () => mockCollectionService.createInitialCollections(uid),
      ).thenAnswer((_) async {});

      final result = await authService.signUp(email: email, password: password);

      expect(result, mockUserCredential);
      verify(
        () => mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      ).called(1);
    });

    test('signUp calls createInitialCollections on new user', () async {
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
      when(
        () => mockCollectionService.createInitialCollections(uid),
      ).thenAnswer((_) async {});

      await authService.signUp(email: email, password: password);

      verify(
        () => mockCollectionService.createInitialCollections(uid),
      ).called(1);
    });

    test('signUp retries createInitialCollections and succeeds', () async {
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

      int createCollectionsCallCount = 0;
      when(
        () => mockCollectionService.createInitialCollections(uid),
      ).thenAnswer((_) async {
        createCollectionsCallCount++;
        if (createCollectionsCallCount == 1) {
          throw Exception('Failed to create collections');
        }
      });

      await authService.signUp(email: email, password: password);

      verify(
        () => mockCollectionService.createInitialCollections(uid),
      ).called(2);
    });

    test('signUp retries createInitialCollections and finally fails', () async {
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
      when(
        () => mockCollectionService.createInitialCollections(uid),
      ).thenThrow(Exception('Failed to create collections'));

      await authService.signUp(email: email, password: password);

      verify(
        () => mockCollectionService.createInitialCollections(uid),
      ).called(3);
      verify(
        () => mockLogger.e(
          any(),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(2);
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

    test('signInWithFacebook throws when access token is null', () async {
      final mockResult = MockLoginResult();

      when(() => mockFacebookAuth.login()).thenAnswer((_) async => mockResult);
      when(() => mockResult.accessToken).thenReturn(null);

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
    });

    test('deleteAccount deletes the Firebase account', () async {
      const uid = 'some-uid';
      final mockUser = MockUser();
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.isAnonymous).thenReturn(false);
      when(() => mockUser.uid).thenReturn(uid);
      when(() => mockUser.delete()).thenAnswer((_) async {});
      await authService.deleteAccount();
      verify(() => mockUser.delete()).called(1);
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

    test('auth stream waits for guest collection provisioning', () async {
      final user = MockUser();
      final provisioning = Completer<void>();
      final started = Completer<void>();
      when(() => user.uid).thenReturn('guest');
      when(() => mockFirebaseAuth.currentUser).thenReturn(user);
      when(() => mockUserCredential.user).thenReturn(user);
      when(
        () => mockFirebaseAuth.authStateChanges(),
      ).thenAnswer((_) => Stream.value(user));
      when(
        () => mockFirebaseAuth.signInAnonymously(),
      ).thenAnswer((_) async => mockUserCredential);
      when(
        () => mockCollectionService.createInitialCollections('guest'),
      ).thenAnswer((_) {
        started.complete();
        return provisioning.future;
      });

      final signIn = authService.signInAsGuest();
      var emitted = false;
      final authEvent = authService.authStateChanges.first.then((value) {
        emitted = true;
        return value;
      });
      await started.future;
      expect(emitted, isFalse);

      provisioning.complete();
      expect(await authEvent, user);
      await signIn;
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

class FakeAuthCredential extends Fake implements AuthCredential {}

class MockAccessToken extends Mock implements AccessToken {}

class MockFacebookAuth extends Mock implements FacebookAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

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

class MockCollectionService extends Mock implements CollectionService {}

class MockLogger extends Mock implements Logger {}

class MockCollectionRepository extends Mock implements ICollectionRepository {}
