import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../interfaces/i_account_data_repository.dart';
import '../interfaces/i_preferences_repository.dart';

@LazySingleton(as: IAccountDataRepository)
class AccountDataRepository implements IAccountDataRepository {
  const AccountDataRepository(this._firestore, this._preferences);

  final FirebaseFirestore _firestore;
  final IPreferencesRepository _preferences;
  static const _batchSize = 500;

  @override
  Future<void> deleteForUser(String userId) async {
    await _deleteOwnedDocuments('products', userId);
    await _deleteOwnedDocuments('collections', userId);
    await _preferences.deleteForUser(userId);
    await _firestore.doc('users/$userId').delete();
  }

  Future<void> _deleteOwnedDocuments(String collection, String userId) async {
    final query = _firestore
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .limit(_batchSize);
    while (true) {
      final page = await query.get(const GetOptions(source: Source.server));
      if (page.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in page.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
      if (page.docs.length < _batchSize) return;
    }
  }
}
