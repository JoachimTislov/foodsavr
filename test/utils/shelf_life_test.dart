import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/utils/shelf_life.dart';

void main() {
  final service = ShelfLifeService();
  final addedDate = DateTime.utc(2026, 11, 22);
  const product = Product(
    id: 'milk',
    name: 'TINE LETTMELK 1L',
    description: '',
    userId: 'user',
  );

  test('first recognized tag takes precedence over category', () {
    expect(
      service.estimateExpiration(
        product.copyWith(
          tags: ['unknown', ' EN:MILKS ', 'en:breads'],
          category: 'meat',
        ),
        addedDate: addedDate,
      ),
      DateTime.utc(2026, 12, 2),
    );
  });

  test('unknown tags fall back to the existing category estimate', () {
    expect(
      service.estimateExpiration(
        product.copyWith(tags: ['unknown'], category: 'Dairy'),
        addedDate: addedDate,
      ),
      DateTime.utc(2026, 12, 2),
    );
  });

  test('no recognized tags or category yields no date', () {
    expect(service.estimateExpiration(product, addedDate: addedDate), isNull);
  });
}
