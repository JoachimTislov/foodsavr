import '../models/user.dart';
import '../interfaces/user_repository.dart';

/// In-memory implementation of IUserRepository.
/// Used for testing and initial seeding. Data is not persisted.
class InMemoryUserRepository implements IUserRepository {
  final List<User> _users = [];

  @override
  Future<User> addUser(User user) async {
    _users.add(user);
    return user;
  }

  @override
  Future<User?> getUser(int id) async {
    try {
      return _users.firstWhere((user) => user.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateUser(User user) async {
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
    }
  }

  @override
  Future<void> deleteUser(int id) async {
    _users.removeWhere((user) => user.id == id);
  }

  @override
  Future<List<User>> getAllUsers() async {
    return List.unmodifiable(_users);
  }
}
