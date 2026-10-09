import 'package:foodsavr_core/src/line_item.dart';
import 'package:test/test.dart';

void main() {
  group('LineItem', () {
    test('copyWith overrides only given fields', () {
      final i = LineItem(
        id: 'x',
        rawName: 'Melk',
        normalizedName: 'melk',
        quantity: 1,
        source: IngestionSource.receipt,
      );
      final c = i.copyWith(matchedProductId: 'p1', matchConfidence: 0.9);
      expect(c.matchedProductId, 'p1');
      expect(c.matchConfidence, 0.9);
      expect(c.rawName, 'Melk');
      expect(c.source, IngestionSource.receipt);
      expect(c.id, 'x');
    });

    test('registeredAt falls back to purchasedAt', () {
      final t = DateTime(2026, 1, 1);
      final i = LineItem(
        id: 'x',
        rawName: 'Melk',
        purchasedAt: t,
        source: IngestionSource.loyaltyApi,
      );
      expect(i.registeredAt, t);
    });

    test('equality is value-based', () {
      final a = LineItem(id: 'x', rawName: 'Melk');
      final b = LineItem(id: 'x', rawName: 'Melk');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('rejects non-positive quantity', () {
      expect(
        () => LineItem(id: 'x', rawName: 'Melk', quantity: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
