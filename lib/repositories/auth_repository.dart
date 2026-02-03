import 'package:firebase_auth/firebase_auth.dart';
import '../interfaces/auth_repository.dart';

/// Firebase implementation of IAuthRepository.
class FirebaseAuthRepository implements IAuthRepository {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthRepository(FirebaseAuth firebaseAuth)
      : _firebaseAuth = firebaseAuth;

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async =>
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

  @override
  Future<UserCredential?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async =>
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

  @override
  Future<void> signOut() => _firebaseAuth.signOut();
}
