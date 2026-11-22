import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/list_query.dart';
import 'package:foodsavr/models/product_model.dart';

void main() {
  test('combines search, category, status, collection and expiry order', () {
    final now = DateTime(2026, 11, 22);
    Product product(String id, int days, {String category = 'Dairy'}) =>
        Product(
          id: id,
          name: id,
          description: 'Cultured',
          barcode: '1234',
          userId: 'user',
          category: category,
          expiries: [
            ExpiryEntry(
              quantity: 1,
              expirationDate: now.add(Duration(days: days)),
            ),
          ],
        );

    final result =
        const ListQuery(
          search: ' CULTURED ',
          category: 'Dairy',
          status: ProductStatus.expiringSoon,
          collectionId: 'fridge',
          sort: ListSort.expiry,
        ).apply(
          [
            product('later', 4),
            product('wrong collection', 0),
            product('expired', -1),
            product('wrong category', 1, category: 'Other'),
            product('wrong search', 1).copyWith(description: ''),
            product('soonest', 1),
          ],
          now: now,
          expiringSoonDays: 5,
          collectionProductIds: {
            'fridge': {
              'later',
              'expired',
              'wrong category',
              'wrong search',
              'soonest',
            },
          },
        );
    expect(result.map((product) => product.id), ['soonest', 'later']);
  });
}
