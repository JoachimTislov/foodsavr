import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../interfaces/i_account_data_repository.dart';
import '../interfaces/i_preferences_repository.dart';

@LazySingleton(as: IAccountDataRepository)
class AccountDataRepository implements IAccountDataRepository {
  const AccountDataRepository(this._firestore, this._preferences);

  final FirebaseFirestore _firestore;
  final IPreferencesRepository _preferences;

  @override
  Future<void> deleteForUser(String userId) => _preferences.deleteForUser(
    userId,
    () async {
      final products = await _ownedDocuments('products', userId);
      final collections = await _ownedDocuments('collections', userId);
      final batch = _firestore.batch();

      for (final document in [...products, ...collections]) {
        batch.delete(document.reference);
      }
      batch.delete(_firestore.doc('users/$userId/settings/preferences'));
      batch.delete(_firestore.doc('users/$userId'));
      // Keep cleanup atomic even when the account owns more than 500 documents.
      await batch.commit();
    },
  );

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _ownedDocuments(
    String collection,
    String userId,
  ) async {
    final snapshot = await _firestore
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs;
  }
}
