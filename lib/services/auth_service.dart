import 'package:firebase_auth/firebase_auth.dart';

import '../interfaces/auth_service.dart';

class AuthService implements IAuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService(this._firebaseAuth);

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<UserCredential?> authenticate({
    required bool isLogin,
    required String email,
    required String password,
  }) {
    if (isLogin) {
      return _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } else {
      return _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}
