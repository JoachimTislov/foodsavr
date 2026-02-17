import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

import '../interfaces/auth_service_interface.dart';

class AuthService implements IAuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FacebookAuth _facebookAuth;
  final Logger _logger;

  AuthService(
    this._firebaseAuth,
    this._googleSignIn,
    this._facebookAuth,
    this._logger,
  );

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
    if (rememberMe) {
      await _firebaseAuth.setPersistence(Persistence.LOCAL);
    } else {
      await _firebaseAuth.setPersistence(Persistence.SESSION);
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
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'google-sign-in-aborted',
        message: 'Google sign-in process was aborted.',
      );
    }

    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<UserCredential> signInWithFacebook() async {
    final LoginResult result = await _facebookAuth.login();
    if (result.status == LoginStatus.success) {
      final AccessToken accessToken = result.accessToken!;
      final AuthCredential credential = FacebookAuthProvider.credential(
        accessToken.token,
      );
      return _firebaseAuth.signInWithCredential(credential);
    } else if (result.status == LoginStatus.cancelled) {
      throw FirebaseAuthException(
        code: 'facebook-sign-in-cancelled',
        message: 'Facebook sign-in process was cancelled.',
      );
    } else {
      _logger.e(
        'Facebook sign-in failed with status: ${result.status} and message: ${result.message}',
      );
      throw FirebaseAuthException(
        code: 'facebook-sign-in-failed',
        message: result.message ?? 'Unknown Facebook sign-in error.',
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  @override
  String? getUserId() {
    return _firebaseAuth.currentUser?.uid;
  }
}
