import 'package:firebase_auth/firebase_auth.dart';

abstract class IAuthService {
  Future<UserCredential> signUp({
    required String email,
    required String password,
  });
  Future<UserCredential> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  });
  Future<UserCredential> signInWithGoogle();
  Future<UserCredential> signInWithFacebook();
  Future<UserCredential> signInAsGuest();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  });
  Future<void> signOut();
  Future<void> deleteAccount({bool reauthenticate = false, String? password});
  Stream<User?> get authStateChanges;
  User? get currentUser;
  String? getUserId();

  /// Adds email and password sign-in to the signed-in account.
  Future<void> linkPasswordCredential({
    required String email,
    required String password,
  });

  /// Adds Google sign-in to the signed-in account.
  Future<void> linkGoogleProvider();

  /// Adds Facebook sign-in to the signed-in account.
  Future<void> linkFacebookProvider();
}
