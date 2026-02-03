import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/auth_repository.dart';

class AuthService {
  final AuthRepository _authRepository;

  AuthService(this._authRepository);

  Stream<User?> get authStateChanges => _authRepository.authStateChanges;

  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) {
    return _authRepository.signInWithEmailAndPassword(email, password);
  }

  Future<UserCredential?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) {
    return _authRepository.createUserWithEmailAndPassword(email, password);
  }

  Future<void> signOut() {
    return _authRepository.signOut();
  }
}
