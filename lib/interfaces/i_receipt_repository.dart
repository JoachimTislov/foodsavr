import '../models/receipt_record.dart';

/// Stores one create-only record per ingested receipt, so scanning the same
/// receipt again can be detected.
abstract class IReceiptRepository {
  /// Whether [userId] already ingested the receipt with id [receiptId].
  Future<bool> exists(String userId, String receiptId);

  /// Writes [record]; returns false and writes nothing when it already
  /// exists.
  Future<bool> create(String userId, ReceiptRecord record);
}
