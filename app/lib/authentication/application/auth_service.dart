import 'package:firebase_auth/firebase_auth.dart';
import '../domain/auth_repository.dart';

class AuthService {
  final AuthRepository _authRepository;

  AuthService(this._authRepository);

  Stream<User?> get authStateChanges => _authRepository.authStateChanges;

  Future<User?> signInWithEmailAndPassword(String email, String password) {
    return _authRepository.signInWithEmailAndPassword(email, password);
  }

  Future<User?> createUserWithEmailAndPassword(String email, String password) {
    return _authRepository.createUserWithEmailAndPassword(email, password);
  }

  Future<void> signOut() {
    return _authRepository.signOut();
  }
}
