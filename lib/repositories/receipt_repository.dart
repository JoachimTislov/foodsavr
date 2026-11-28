import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../interfaces/i_receipt_repository.dart';
import '../models/receipt_record.dart';

/// Firestore implementation of [IReceiptRepository]. Records are ADR 0005
/// inbox documents at `owners/{uid}/rawEvents/receipt:<store>:<hash>`; rules
/// allow create only, so an existing receipt can never be overwritten.
@LazySingleton(as: IReceiptRepository)
class ReceiptRepository implements IReceiptRepository {
  static const _schemaVersion = 1;

  final FirebaseFirestore _firestore;

  ReceiptRepository(this._firestore);

  DocumentReference<Map<String, dynamic>> _doc(String userId, String id) =>
      _firestore
          .collection('owners')
          .doc(userId)
          .collection('rawEvents')
          .doc(id);

  @override
  Future<bool> exists(String userId, String receiptId) async {
    final snapshot = await _doc(userId, receiptId).get();
    return snapshot.exists;
  }

  @override
  Future<bool> create(String userId, ReceiptRecord record) async {
    final doc = _doc(userId, record.id);
    if ((await doc.get()).exists) return false;
    await doc.set({
      'id': record.id,
      'ownerId': userId,
      'source': 'receipt',
      'provider': record.provider,
      'externalId': record.externalId,
      'occurredAt': Timestamp.fromDate(record.occurredAt),
      'receivedAt': FieldValue.serverTimestamp(),
      'payload': record.payload,
      'schemaVersion': _schemaVersion,
    });
    return true;
  }

  @override
  Future<List<ReceiptRecord>> list(String userId) async {
    final snapshot = await _firestore
        .collection('owners')
        .doc(userId)
        .collection('rawEvents')
        .where('source', isEqualTo: 'receipt')
        .get();
    // Sorted here to avoid a composite index on source and occurredAt.
    return snapshot.docs
        .map((d) => ReceiptRecord.fromFirestore(d.data()))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }
}
