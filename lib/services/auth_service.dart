import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';

import '../interfaces/i_auth_service.dart';

@LazySingleton(as: IAuthService)
class AuthService implements IAuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FacebookAuth _facebookAuth;
  final bool _supportsPersistence;

  AuthService(this._firebaseAuth,
      {required GoogleSignIn googleSignIn,
      required FacebookAuth facebookAuth,
      required bool supportsPersistence})
      : _googleSignIn = googleSignIn,
        _facebookAuth = facebookAuth,
        _supportsPersistence = supportsPersistence;

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
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  @override
  /// Signs in a user with Facebook.
  ///
  /// Throws:
  /// - [FirebaseAuthException] if sign-in fails or is aborted by the user.
  Future<UserCredential> signInWithFacebook() async {
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
