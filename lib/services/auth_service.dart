import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/auth_repository.dart';

class AuthService {
  final AuthRepository _authRepository;

  AuthService(this._authRepository);

  Stream<User?> get authStateChanges => _authRepository.authStateChanges;

  String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email cannot be empty.';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password cannot be empty.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) {
    final emailError = validateEmail(email);
    final passwordError = validatePassword(password);

    if (emailError != null) {
      throw Exception(emailError);
    }
    if (passwordError != null) {
      throw Exception(passwordError);
    }

    return _authRepository.signInWithEmailAndPassword(email, password);
  }

  Future<UserCredential?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) {
    final emailError = validateEmail(email);
    final passwordError = validatePassword(password);

    if (emailError != null) {
      throw Exception(emailError);
    }
    if (passwordError != null) {
      throw Exception(passwordError);
    }

    return _authRepository.createUserWithEmailAndPassword(email, password);
  }

  Future<void> signOut() {
    return _authRepository.signOut();
  }
}
