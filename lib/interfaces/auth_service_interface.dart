import 'package:firebase_auth/firebase_auth.dart';

abstract class IAuthService {
  Future<UserCredential?> authenticate({
    required bool isLogin,
    required String email,
    required String password,
  });
  Future<void> signOut();
  Stream<User?> get authStateChanges;
  String? getUserId();
}
