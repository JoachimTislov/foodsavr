import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/utils/retry.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_auth_service.dart';

@LazySingleton(as: IAuthService)
class AuthService implements IAuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FacebookAuth _facebookAuth;
  final bool _supportsPersistence;
  final bool _isWeb;
  final FirebaseFirestore _firestore;
  final CollectionService _collectionService;
  final Logger _logger;

  AuthService(
    this._firebaseAuth, {
    required GoogleSignIn googleSignIn,
    required FacebookAuth facebookAuth,
    @Named('supportsPersistence') required bool supportsPersistence,
    @Named('isWeb') required bool isWeb,
    required FirebaseFirestore firestore,
    required CollectionService collectionService,
    required Logger logger,
  }) : _googleSignIn = googleSignIn,
       _facebookAuth = facebookAuth,
       _supportsPersistence = supportsPersistence,
       _isWeb = isWeb,
       _firestore = firestore,
       _collectionService = collectionService,
       _logger = logger;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  /// Signs in a user with email and password.
  ///
  /// Throws:
  /// - [FirebaseAuthException] if sign-in fails.
  Future<UserCredential> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    if (_supportsPersistence) {
      if (rememberMe) {
        await _firebaseAuth.setPersistence(Persistence.LOCAL);
      } else {
        await _firebaseAuth.setPersistence(Persistence.SESSION);
      }
    }
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  /// Signs up a user with email and password.
  ///
  /// Throws:
  /// - [FirebaseAuthException] if sign-up fails.
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser?.isAnonymous == true) {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      return currentUser!.linkWithCredential(credential);
    }
    final newUser = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (newUser.user != null) {
      try {
        await retry(
          () => _collectionService.createInitialCollections(newUser.user!.uid),
          logger: _logger,
          operationName: 'CreateInitialCollections',
        );
      } catch (e, s) {
        _logger.e(
          'Failed to create initial collections for user ${newUser.user!.uid} after multiple retries. The user account was created, but seeding failed.',
          error: e,
          stackTrace: s,
        );
        // Do not rethrow; allow signup to succeed.
      }
    }
    return newUser;
  }

  Future<void>? _googleSignInInitialization;

  @override
  /// Signs in a user with Google.
  ///
  /// Web uses the Firebase popup flow; native platforms use `google_sign_in`,
  /// which must be initialized once before [GoogleSignIn.authenticate].
  Future<UserCredential> signInWithGoogle() async {
    if (_isWeb) {
      return _signInWithPopup(GoogleAuthProvider());
    }
    await (_googleSignInInitialization ??= _initializeGoogleSignIn());
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }
      rethrow;
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
    } catch (_) {
      // Allow a retry on the next attempt instead of caching the failure.
      _googleSignInInitialization = null;
      rethrow;
    }
  }

  @override
  /// Signs in a user with Facebook.
  ///
  /// Throws:
  /// - [FirebaseAuthException] if sign-in fails or is aborted by the user.
  Future<UserCredential> signInWithFacebook() async {
    if (_isWeb) {
      return _signInWithPopup(FacebookAuthProvider());
    }
    // Trigger the sign-in flow
    final LoginResult loginResult = await _facebookAuth.login();
    final AccessToken? accessToken = loginResult.accessToken;
    if (accessToken == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Sign in aborted by user',
      );
    }

    // Create a credential from the access token
    final OAuthCredential facebookAuthCredential =
        FacebookAuthProvider.credential(accessToken.tokenString);

    // Once signed in, return the UserCredential
    return _firebaseAuth.signInWithCredential(facebookAuthCredential);
  }

  Future<UserCredential> _signInWithPopup(AuthProvider provider) async {
    try {
      return await _firebaseAuth.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }
      rethrow;
    }
  }

  @override
  Future<UserCredential> signInAsGuest() {
    return _firebaseAuth.signInAnonymously();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.isAnonymous || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in email account to update.',
      );
    }

    final hasPasswordProvider = user.providerData.any(
      (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
    );
    if (!hasPasswordProvider) {
      throw FirebaseAuthException(
        code: 'operation-not-allowed-in-current-mode',
        message:
            'Email change requires an account with a linked password provider.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(newEmail);
    _logger.i('Verification email sent for email change.');
  }

  @override
  Future<void> signOut() {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser?.isAnonymous == true) {
      return _cleanupAndSignOutAnonymousUser(currentUser!);
    }
    return _firebaseAuth.signOut();
  }

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  String? getUserId() {
    return _firebaseAuth.currentUser?.uid;
  }

  Future<void> _cleanupAndSignOutAnonymousUser(User user) async {
    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    try {
      await _deleteDocumentsForUser(
        collectionName: 'products',
        userId: user.uid,
      );
      await _deleteDocumentsForUser(
        collectionName: 'collections',
        userId: user.uid,
      );
      await user.delete();
    } catch (e, st) {
      cleanupError = e;
      cleanupStackTrace = st;
    } finally {
      await _firebaseAuth.signOut();
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStackTrace!);
    }
  }

  Future<void> _deleteDocumentsForUser({
    required String collectionName,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .get();
    if (snapshot.docs.isEmpty) {
      return;
    }
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
