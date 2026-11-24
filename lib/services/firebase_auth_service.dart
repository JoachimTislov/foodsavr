import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/utils/retry.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_account_data_repository.dart';
import '../interfaces/i_auth_service.dart';
import '../interfaces/i_error_reporter.dart';
import 'secure_storage_service.dart';

@LazySingleton(as: IAuthService)
class AuthService implements IAuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FacebookAuth _facebookAuth;
  final bool _supportsPersistence;
  final bool _isWeb;
  final IAccountDataRepository _accountDataRepository;
  final SecureStorage _secureStorage;
  final CollectionService _collectionService;
  final Logger _logger;
  final IErrorReporter _errorReporter;

  AuthService(
    this._firebaseAuth, {
    required GoogleSignIn googleSignIn,
    required FacebookAuth facebookAuth,
    @Named('supportsPersistence') required bool supportsPersistence,
    @Named('isWeb') required bool isWeb,
    required IAccountDataRepository accountDataRepository,
    required SecureStorage secureStorage,
    required CollectionService collectionService,
    required Logger logger,
    required IErrorReporter errorReporter,
  }) : _googleSignIn = googleSignIn,
       _facebookAuth = facebookAuth,
       _supportsPersistence = supportsPersistence,
       _isWeb = isWeb,
       _accountDataRepository = accountDataRepository,
       _secureStorage = secureStorage,
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
    final credential = await _googleCredential();
    return _authenticate(() => _firebaseAuth.signInWithCredential(credential));
  }

  Future<OAuthCredential> _googleCredential() async {
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

    return GoogleAuthProvider.credential(
      idToken: googleUser.authentication.idToken,
    );
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
    final credential = await _facebookCredential();
    return _authenticate(() => _firebaseAuth.signInWithCredential(credential));
  }

  Future<OAuthCredential> _facebookCredential() async {
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

    return FacebookAuthProvider.credential(token);
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
    try {
      await _deleteUser(user);
    } finally {
      await _firebaseAuth.signOut();
    }
  }

  @override
  Future<void> deleteAccount({
    bool reauthenticate = false,
    String? password,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    if (!user.isAnonymous) {
      if (!reauthenticate) {
        throw FirebaseAuthException(code: 'requires-recent-login');
      }
      await _reauthenticate(user, password);
    }
    await _deleteUser(user);
  }

  Future<void> _deleteUser(User user) async {
    _requireCurrentUser(user);
    await _accountDataRepository.deleteForUser(user.uid);
    _requireCurrentUser(user);
    await user.delete();
    try {
      await _secureStorage.clearStoreTokens();
    } catch (error, stack) {
      _logger.w(
        'Could not clear deleted account store tokens',
        error: error,
        stackTrace: stack,
      );
    }
    _logger.i('User account deleted: ${user.uid}');
  }

  void _requireCurrentUser(User user) {
    if (_firebaseAuth.currentUser?.uid != user.uid) {
      throw FirebaseAuthException(code: 'user-mismatch');
    }
  }

  Future<void> _reauthenticate(User user, String? password) async {
    final providers = user.providerData.map((info) => info.providerId).toSet();
    if (providers.contains(EmailAuthProvider.PROVIDER_ID) &&
        user.email != null) {
      if (password == null) {
        throw FirebaseAuthException(code: 'requires-recent-login');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } else if (providers.contains(GoogleAuthProvider.PROVIDER_ID)) {
      if (_isWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
      } else {
        await user.reauthenticateWithCredential(await _googleCredential());
      }
    } else if (providers.contains(FacebookAuthProvider.PROVIDER_ID)) {
      if (_isWeb) {
        await user.reauthenticateWithPopup(FacebookAuthProvider());
      } else {
        await user.reauthenticateWithCredential(await _facebookCredential());
      }
    } else {
      throw FirebaseAuthException(
        code: 'operation-not-allowed-in-current-mode',
      );
    }
  }
}
