import 'package:firebase_auth/firebase_auth.dart';

/// Abstract interface for authentication operations.
/// Implementations can use Firebase Auth or any other auth provider.
abstract class IAuthRepository {
  Stream<User?> get authStateChanges;
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  );
  Future<UserCredential?> createUserWithEmailAndPassword(
    String email,
    String password,
  );
  Future<void> signOut();
}
