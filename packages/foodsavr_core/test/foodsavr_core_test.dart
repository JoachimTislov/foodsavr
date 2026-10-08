import 'package:foodsavr_core/foodsavr_core.dart';
import 'package:test/test.dart';

void main() {
  group('LineItem', () {
    test('round-trips through JSON', () {
      final item = LineItem(
        rawName: '1l Milk',
        normalizedName: '1l milk',
        quantity: 1,
        unit: 'l',
        price: 19.9,
        source: LineItemSource.receipt,
        barcode: '1234567890123',
        purchasedAt: DateTime(2026, 10, 1),
        productId: 'p1',
        matchConfidence: 0.9,
        category: 'dairy',
      );
      final restored = LineItem.fromJson(item.toJson());
      expect(restored, item);
    });
  });

  group('Normalizer', () {
    final normalizer = Normalizer();

    test('normalizes case, whitespace and unit synonyms', () {
      expect(normalizer.normalizeName('  Milk   1 L '), 'milk 1 l');
      expect(normalizer.normalizeName('2 KILO kg kjøtt'), '2 kg kg kjøtt');
      expect(normalizer.normalizeName('Brød'), 'brød');
    });

    test('extracts quantity and unit', () {
      expect(
        normalizer.extractQuantity('1l milk'),
        (quantity: 1.0, unit: 'l'),
      );
      expect(
        normalizer.extractQuantity('Milk 0,5 L'),
        (quantity: 0.5, unit: 'l'),
      );
      expect(
        normalizer.extractQuantity('Kjøtt 750 g'),
        (quantity: 750.0, unit: 'g'),
      );
      expect(normalizer.extractQuantity('Milk'), isNull);
    });

    test('normalize fills quantity and unit from raw name', () {
      final item = normalizer.normalize(
        LineItem(rawName: 'Milk 1 L', quantity: 1, source: LineItemSource.text),
      );
      expect(item.normalizedName, 'milk 1 l');
      expect(item.quantity, 1.0);
      expect(item.unit, 'l');
    });

    test('keeps default quantity when none embedded', () {
      final item = normalizer.normalize(
        LineItem(rawName: 'Bread', quantity: 2, source: LineItemSource.api),
      );
      expect(item.quantity, 2);
      expect(item.unit, isNull);
    });
  });

  group('FuzzyMatcher', () {
    test('matches identical names with confidence 1', () {
      final matcher = FuzzyMatcher(catalog: {'p1': 'Tine Melk Lettmelk 1l'});
      final result = matcher.bestMatch(
        LineItem(
          rawName: 'tine melk lettmelk 1l',
          quantity: 1,
          source: LineItemSource.receipt,
        ),
      );
      expect(result, isNotNull);
      expect(result!.productId, 'p1');
      expect(result.confidence, 1.0);
    });

    test('fuzzy-matches typos', () {
      final matcher = FuzzyMatcher(catalog: {'p1': 'lett melk'});
      final result = matcher.bestMatch(
        LineItem(
          rawName: 'ltet melk',
          quantity: 1,
          source: LineItemSource.receipt,
        ),
      );
      expect(result, isNotNull);
      expect(result!.confidence, greaterThan(0.5));
    });

    test('token-set match handles reordered words', () {
      final matcher = FuzzyMatcher(catalog: {'p1': 'melk lettmelk'});
      final result = matcher.bestMatch(
        LineItem(
          rawName: 'lettmelk melk',
          quantity: 1,
          source: LineItemSource.api,
        ),
      );
      expect(result, isNotNull);
      expect(result!.confidence, greaterThan(0.5));
    });

    test('returns null below min confidence', () {
      final matcher = FuzzyMatcher(catalog: {'p1': 'melk'});
      expect(
        matcher.bestMatch(
          LineItem(
            rawName: 'kjøttdeig',
            quantity: 1,
            source: LineItemSource.text,
          ),
        ),
        isNull,
      );
    });
  });

  group('ShelfLifeInferer', () {
    test('category defaults', () {
      final inferer = ShelfLifeInferer();
      expect(inferer.inferDays(category: 'dairy'), 7);
      expect(inferer.inferDays(category: 'Fish'), 2);
      expect(inferer.inferDays(category: 'unknown'), 14);
    });

    test('product override wins over category', () {
      final inferer = ShelfLifeInferer(overrides: {'p1': 3});
      expect(inferer.inferDays(category: 'dairy', productId: 'p1'), 3);
      expect(inferer.inferDays(category: 'dairy', productId: 'p2'), 7);
    });
  });

  group('ConfidenceGate', () {
    final gate = ConfidenceGate();
    LineItem item(double? c) => LineItem(
      rawName: 'x',
      quantity: 1,
      source: LineItemSource.receipt,
      matchConfidence: c,
    );

    test('auto-add at high confidence', () {
      expect(gate.evaluate(item(0.95)), GateDecision.autoAdd);
    });

    test('confirm at medium confidence', () {
      expect(gate.evaluate(item(0.6)), GateDecision.confirm);
    });

    test('hold at low or missing confidence', () {
      expect(gate.evaluate(item(0.3)), GateDecision.hold);
      expect(gate.evaluate(item(null)), GateDecision.hold);
    });
  });
}
