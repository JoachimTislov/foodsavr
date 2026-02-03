import '../models/user.dart';

class UserRepository {
  final List<User> _users = [];

  // User methods
  Future<User> addUser(User user) async {
    _users.add(user);
    return user;
  }

  Future<User?> getUser(int id) async {
    return _users.firstWhere((user) => user.id == id);
  }

  Future<void> updateUser(User user) async {
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
    }
  }

  Future<void> deleteUser(int id) async {
    _users.removeWhere((user) => user.id == id);
  }
}
