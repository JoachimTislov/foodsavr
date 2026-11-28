import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';

void main() {
  final product = Product(
    id: 'p',
    name: 'Milk',
    description: '',
    userId: 'u',
    expiries: [ExpiryEntry(quantity: 2, expirationDate: DateTime(2027, 1, 1))],
  );

  test('a new day is appended', () {
    final changed = product.withExpiry(DateTime(2027, 2, 1), quantity: 3);

    expect(changed.expiries, hasLength(2));
    expect(changed.expiries.last.quantity, 3);
    expect(changed.quantity, 5);
  });

  test('the same calendar day is merged', () {
    final changed = product.withExpiry(DateTime(2027, 1, 1, 15));

    expect(changed.expiries.single.quantity, 3);
  });
}
