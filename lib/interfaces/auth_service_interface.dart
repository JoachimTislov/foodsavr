import 'package:firebase_auth/firebase_auth.dart';

abstract class IAuthService {
  Future<UserCredential> signUp({
    required String email,
    required String password,
  });
  Future<UserCredential> signIn({
    required String email,
    required String password,
  });
  Future<void> signOut();
  Stream<User?> get authStateChanges;
  String? getUserId();
}
