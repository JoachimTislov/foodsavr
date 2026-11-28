import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/purchase_history_service.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

Product _product(String id) => Product(
  id: id,
  name: id,
  description: '',
  userId: 'user-1',
  nonExpiringQuantity: 2,
);

void main() {
  late PurchaseHistoryService history;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    history = PurchaseHistoryService(Logger(level: Level.off));
  });

  test('overlapping purchases are all kept, newest first', () async {
    await Future.wait([
      history.record('user-1', [_product('milk')], PurchaseSource.manual),
      history.record('user-1', [_product('eggs')], PurchaseSource.receipt),
    ]);

    final entries = await history.load('user-1');
    expect(entries.map((entry) => entry['productId']), ['eggs', 'milk']);
    expect(entries.first['source'], 'receipt');
    expect(entries.first['quantity'], 2);
  });

  test('keeps only the newest entries', () async {
    await history.record('user-1', [
      for (var i = 0; i < PurchaseHistoryService.maxEntries; i++)
        _product('old-$i'),
    ], PurchaseSource.manual);

    final entries = await history.record('user-1', [
      _product('new'),
    ], PurchaseSource.manual);

    expect(entries, hasLength(PurchaseHistoryService.maxEntries));
    expect(entries.first['productId'], 'new');
  });

  test('unreadable stored history is replaced', () async {
    SharedPreferences.setMockInitialValues({
      'purchase_history_user-1': 'not json',
    });

    expect(await history.load('user-1'), isEmpty);
  });
}
