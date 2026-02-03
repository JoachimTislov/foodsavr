import '../models/user.dart';

/// Abstract interface for user data access operations.
/// Implementations can be in-memory, Firestore, or any other data source.
abstract class IUserRepository {
  Future<User> addUser(User user);
  Future<User?> getUser(int id);
  Future<void> updateUser(User user);
  Future<void> deleteUser(int id);
  Future<List<User>> getAllUsers();
}
