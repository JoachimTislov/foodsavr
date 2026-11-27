import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/product_categories.dart';
import 'package:foodsavr/mock_data/global_products.dart';

/// GS1 check digit of the first twelve digits of an EAN-13.
int _checkDigit(String digits) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(digits[i]) * (i.isEven ? 1 : 3);
  }
  return (10 - sum % 10) % 10;
}

void main() {
  final products = GlobalProductsData.getProducts();

  List<String> values(String field) => [
    for (final product in products) product[field] as String,
  ];

  test('offers a catalog of essentials', () {
    expect(products.length, inInclusiveRange(25, 30));
  });

  test('every product has non-empty string fields', () {
    for (final product in products) {
      expect(product.keys, {
        'id',
        'name',
        'description',
        'category',
        'barcode',
      });
      for (final value in product.values) {
        expect(
          value,
          isA<String>().having((v) => v.trim(), 'text', isNotEmpty),
        );
      }
    }
  });

  test('ids, names and barcodes are unique', () {
    for (final field in ['id', 'name', 'barcode']) {
      expect(values(field).toSet(), hasLength(products.length), reason: field);
    }
    expect(values('id'), everyElement(matches(r'^global-[a-z0-9-]+$')));
  });

  test('categories are the app categories and each one is covered', () {
    expect(values('category').toSet(), ProductCategory.allKeys.toSet());
  });

  test('the check digit matches published EAN-13 examples', () {
    expect(_checkDigit('400638133393'), 1);
    expect(_checkDigit('590123412345'), 7);
  });

  test('every barcode is a valid EAN-13', () {
    for (final barcode in values('barcode')) {
      expect(barcode, matches(r'^\d{13}$'));
      expect(int.parse(barcode[12]), _checkDigit(barcode), reason: barcode);
    }
  });
}
