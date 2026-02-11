import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../interfaces/user_repository.dart';

/// Firestore implementation of IUserRepository.
/// Persists user data in Firestore 'users' collection.
class FirestoreUserRepository implements IUserRepository {
  final FirebaseFirestore _firestore;
  final String _collectionName = 'users';

  FirestoreUserRepository(this._firestore);

  @override
  Future<User> addUser(User user) async {
    await _firestore
        .collection(_collectionName)
        .doc(user.id.toString())
        .set(user.toJson());
    return user;
  }

  @override
  Future<User?> getUser(int id) async {
    final doc = await _firestore
        .collection(_collectionName)
        .doc(id.toString())
        .get();
    if (!doc.exists) return null;
    return User.fromJson(doc.data()!);
  }

  @override
  Future<void> updateUser(User user) async {
    await _firestore
        .collection(_collectionName)
        .doc(user.id.toString())
        .update(user.toJson());
  }

  @override
  Future<void> deleteUser(int id) async {
    await _firestore.collection(_collectionName).doc(id.toString()).delete();
  }

  @override
  Future<List<User>> getAllUsers() async {
    final querySnapshot = await _firestore.collection(_collectionName).get();
    return querySnapshot.docs.map((doc) => User.fromJson(doc.data())).toList();
  }
}
