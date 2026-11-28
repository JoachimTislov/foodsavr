import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/product_model.dart';

void main() {
  final soon = ExpiryEntry(quantity: 2, expirationDate: DateTime(2027, 1, 1));
  final later = ExpiryEntry(quantity: 1, expirationDate: DateTime(2027, 6, 1));
  final product = Product(
    id: 'p',
    name: 'Milk',
    description: '',
    userId: 'u',
    nonExpiringQuantity: 1,
    expiries: [soon, later],
  );

  test('an increase adds undated stock', () {
    final changed = product.adjustQuantity(1);

    expect(changed.quantity, 5);
    expect(changed.nonExpiringQuantity, 2);
  });

  test('a removal takes undated stock, then the latest expiry', () {
    expect(product.adjustQuantity(-1).expiries, [soon, later]);

    final changed = product.adjustQuantity(-2);

    expect(changed.nonExpiringQuantity, 0);
    expect(changed.expiries, [soon]);
  });

  test('the quantity never drops below zero', () {
    final changed = product.adjustQuantity(-10);

    expect(changed.quantity, 0);
    expect(changed.expiries, isEmpty);
  });
}
