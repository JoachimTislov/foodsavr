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
  Future<void> signOut();
  Stream<User?> get authStateChanges;
  User? get currentUser;
  String? getUserId();
}
