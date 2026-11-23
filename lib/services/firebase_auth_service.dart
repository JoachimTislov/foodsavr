import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/utils/retry.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_auth_service.dart';
import '../interfaces/i_error_reporter.dart';

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
  final IErrorReporter _errorReporter;

  AuthService(
    this._firebaseAuth, {
    required GoogleSignIn googleSignIn,
    required FacebookAuth facebookAuth,
    @Named('supportsPersistence') required bool supportsPersistence,
    @Named('isWeb') required bool isWeb,
    required FirebaseFirestore firestore,
    required CollectionService collectionService,
    required Logger logger,
    required IErrorReporter errorReporter,
  }) : _googleSignIn = googleSignIn,
       _facebookAuth = facebookAuth,
       _supportsPersistence = supportsPersistence,
       _isWeb = isWeb,
       _firestore = firestore,
       _collectionService = collectionService,
       _logger = logger,
       _errorReporter = errorReporter;

  Future<void>? _pendingSignIn;

  @override
  Stream<User?> get authStateChanges =>
      _firebaseAuth.authStateChanges().asyncMap((user) async {
        final pendingSignIn = _pendingSignIn;
        if (user == null || pendingSignIn == null) return user;
        await pendingSignIn;
        return _firebaseAuth.currentUser;
      });

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
    return _authenticate(
      () => _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
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
      return _authenticate(() => currentUser!.linkWithCredential(credential));
    }
    return _authenticate(
      () => _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
  }

  Future<UserCredential> _authenticate(
    Future<UserCredential> Function() authenticate,
  ) async {
    final completion = Completer<void>();
    _pendingSignIn = completion.future;
    try {
      final credential = await authenticate();
      final uid = credential.user?.uid;
      if (uid != null) {
        try {
          await retry(
            () => _collectionService.createInitialCollections(uid),
            logger: _logger,
            operationName: 'CreateInitialCollections',
          );
        } catch (error, stackTrace) {
          _logger.e(
            'Signed in successfully but could not provision initial collections.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      return credential;
    } finally {
      completion.complete();
      if (identical(_pendingSignIn, completion.future)) _pendingSignIn = null;
    }
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

    return _authenticate(() => _firebaseAuth.signInWithCredential(credential));
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
    try {
      return await (_isWeb
          ? _signInWithPopup(FacebookAuthProvider())
          : _signInWithFacebookSdk());
    } catch (error, stack) {
      final code = error is FirebaseAuthException
          ? error.code
          : error.runtimeType.toString();
      if (code != 'ERROR_ABORTED_BY_USER' &&
          code != 'facebook-sdk-in-progress') {
        // SDK error messages and credentials can contain OAuth tokens.
        final failure = StateError('Facebook sign-in failed ($code)');
        _logger.e(failure.message, stackTrace: stack);
        unawaited(
          _errorReporter.recordError(
            failure,
            stack,
            reason: 'Facebook sign-in',
          ),
        );
      }
      rethrow;
    }
  }

  Future<UserCredential> _signInWithFacebookSdk() async {
    final LoginResult result;
    try {
      result = await _facebookAuth.login();
    } on MissingPluginException catch (_, stack) {
      // Android's plugin registration fails when the Meta SDK could not initialize.
      Error.throwWithStackTrace(
        FirebaseAuthException(code: 'facebook-sdk-unavailable'),
        stack,
      );
    }

    switch (result.status) {
      case LoginStatus.cancelled:
        throw FirebaseAuthException(code: 'ERROR_ABORTED_BY_USER');
      case LoginStatus.failed:
        throw FirebaseAuthException(code: 'facebook-sdk-failed');
      case LoginStatus.operationInProgress:
        throw FirebaseAuthException(code: 'facebook-sdk-in-progress');
      case LoginStatus.success:
        break;
    }
    final token = result.accessToken?.tokenString;
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(code: 'facebook-sdk-failed');
    }

    final credential = FacebookAuthProvider.credential(token);
    return _authenticate(() => _firebaseAuth.signInWithCredential(credential));
  }

  Future<UserCredential> _signInWithPopup(AuthProvider provider) async {
    try {
      return await _authenticate(() => _firebaseAuth.signInWithPopup(provider));
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
    return _authenticate(_firebaseAuth.signInAnonymously);
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

  @override
  Future<void> deleteAccount() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      return;
    }
    if (currentUser.isAnonymous) {
      return _cleanupAndSignOutAnonymousUser(currentUser);
    }
    await currentUser.delete();
    try {
      await _deleteDocumentsForUser(
        collectionName: 'products',
        userId: currentUser.uid,
      );
      await _deleteDocumentsForUser(
        collectionName: 'collections',
        userId: currentUser.uid,
      );
    } catch (e, s) {
      _logger.e(
        'Failed to clean up documents for deleted user ${currentUser.uid}',
        error: e,
        stackTrace: s,
      );
    }
    _logger.i('User account deleted: ${currentUser.uid}');
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
