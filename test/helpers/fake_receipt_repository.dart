import 'package:foodsavr/interfaces/i_receipt_repository.dart';
import 'package:foodsavr/models/receipt_record.dart';

/// An in-memory receipt store; [failing] makes [list] throw.
class FakeReceiptRepository implements IReceiptRepository {
  final List<ReceiptRecord> records;
  final bool failing;

  FakeReceiptRepository({this.records = const [], this.failing = false});

  @override
  Future<bool> create(String userId, ReceiptRecord record) async => true;

  @override
  Future<bool> exists(String userId, String receiptId) async => false;

  @override
  Future<List<ReceiptRecord>> list(String userId) async {
    if (failing) throw StateError('offline');
    return records;
  }
}
