import 'package:foodsavr_core/foodsavr_core.dart';
import 'package:test/test.dart';

LineItem item(String name) =>
    LineItem(id: 'i1', rawName: name, normalizedName: name);

void main() {
  final s = ShelfLifeInferer();

  group('ShelfLifeInferer', () {
    test('returns the first supported tag with its rule and duration', () {
      expect(
        s.estimate(
          tags: ['unknown', ' EN:MILKS ', 'en:breads'],
          category: 'meat',
          normalizedName: 'tine lettmelk 1l',
        ),
        (days: 10, source: ShelfLifeSource.tag, rule: 'en:milks'),
      );
    });

    test('category aliases precede name keywords', () {
      expect(
        s.estimate(
          tags: ['unknown'],
          category: 'Dairy',
          normalizedName: 'laksfilet',
        ),
        (days: 10, source: ShelfLifeSource.category, rule: 'dairy'),
      );
    });

    test('unknown tags and category fall back to normalized name', () {
      expect(
        s.estimate(
          tags: ['unknown'],
          category: 'unknown',
          normalizedName: 'tine lettmelk 1l',
        ),
        (days: 7, source: ShelfLifeSource.name, rule: 'melk'),
      );
      expect(s.estimate(normalizedName: 'wunderbaum'), isNull);
    });

    test('dairy keywords', () {
      expect(s.infer(item('tine melk')), s.defaultFor(FoodCategory.dairy));
      expect(s.infer(item('jarlsberg ost')), s.defaultFor(FoodCategory.dairy));
    });

    test('meat and fish keywords (Norwegian)', () {
      expect(s.infer(item('kyllingfilet')), s.defaultFor(FoodCategory.meat));
      expect(s.infer(item('laksfilet')), s.defaultFor(FoodCategory.fish));
    });

    test('produce and pantry keywords', () {
      expect(s.infer(item('banan')), s.defaultFor(FoodCategory.produce));
      expect(
        s.infer(item('spagetti pasta')),
        s.defaultFor(FoodCategory.pantry),
      );
    });

    test('short keywords do not match inside unrelated words', () {
      expect(s.categorize('toast'), isNull);
      expect(s.categorize('leverpostei'), isNull);
      expect(s.categorize('pistasj'), isNull);
      expect(s.categorize('toast med ost'), FoodCategory.dairy);
      expect(s.categorize('iskrem'), FoodCategory.frozen);
      expect(s.categorize('vaniljeis'), FoodCategory.frozen);
    });
    test('unknown items return null', () {
      expect(s.infer(item('wunderbaum')), isNull);
    });

    test('custom defaults override the built-in table', () {
      final custom = ShelfLifeInferer(
        defaults: {...ShelfLifeInferer.defaultDays, FoodCategory.meat: 5},
      );
      expect(custom.infer(item('kylling')), 5);
    });
  });
}
