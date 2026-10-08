import 'package:foodsavr_core/src/line_item.dart';
import 'package:foodsavr_core/src/matcher.dart';
import 'package:test/test.dart';

LineItem item(String name, {String? barcode, String normalized = ''}) =>
    LineItem(
      id: 'i1',
      rawName: name,
      normalizedName: normalized.isNotEmpty ? normalized : name.toLowerCase(),
      barcode: barcode,
    );

void main() {
  final catalog = [
    const CatalogProduct(id: 'p1', name: 'Tine Melk'),
    const CatalogProduct(id: 'p2', name: 'Brød'),
    const CatalogProduct(id: 'p3', name: 'Jarlsberg Ost', keywords: ['cheese']),
    const CatalogProduct(id: 'p4', name: 'Melk', barcode: '7037320000000'),
  ];

  final m = FuzzyMatcher();

  group('FuzzyMatcher.match', () {
    test('exact barcode wins with confidence 1', () {
      final r = m.match(item('anything', barcode: '7037320000000'), catalog);
      expect(r.product!.id, 'p4');
      expect(r.confidence, 1.0);
    });

    test('exact normalized name gives confidence 1', () {
      final r = m.match(item('Melk', normalized: 'melk'), catalog);
      expect(r.product!.id, 'p4');
      expect(r.confidence, 1.0);
    });

    test('brand-qualified name still matches the base product', () {
      final r = m.match(item('x', normalized: 'tine melk'), catalog);
      expect(r.product!.id, 'p1');
      expect(r.confidence, greaterThan(m.minConfidence));
    });

    test('partial overlap matches the closest candidate', () {
      final r = m.match(item('x', normalized: 'jarlsberg ost'), catalog);
      expect(r.product!.id, 'p3');
      expect(r.confidence, greaterThan(0.5));
    });

    test('unrelated input returns no match', () {
      final r = m.match(item('x', normalized: 'spark plugs'), catalog);
      expect(r.hasMatch, isFalse);
      expect(r.confidence, 0.0);
    });

    test('keywords broaden matching', () {
      final cheese = [
        const CatalogProduct(
          id: 'c1',
          name: 'Norwegian Cheese',
          keywords: ['ost'],
        ),
      ];
      final r = m.match(item('x', normalized: 'hviteost'), cheese);
      expect(r.product!.id, 'c1');
    });

    test('empty normalized name never matches', () {
      final r = m.match(item('!!!', normalized: ''), catalog);
      expect(r.hasMatch, isFalse);
    });
  });
}
