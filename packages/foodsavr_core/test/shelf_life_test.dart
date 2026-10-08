import 'package:foodsavr_core/src/line_item.dart';
import 'package:foodsavr_core/src/shelf_life.dart';
import 'package:test/test.dart';

LineItem item(String name) =>
    LineItem(id: 'i1', rawName: name, normalizedName: name);

void main() {
  final s = ShelfLifeInferer();

  group('ShelfLifeInferer', () {
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
      expect(s.infer(item('spagetti pasta')), s.defaultFor(FoodCategory.pantry));
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
