import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/barcode_validator.dart';

void main() {
  void expectValidity(String input, BarcodeValidity validity) => expect(
    BarcodeValidator.validate(input).validity,
    validity,
    reason: input,
  );

  test('accepts retail barcodes with a matching GS1 check digit', () {
    for (final barcode in [
      '96385074', // EAN-8
      '036000291452', // UPC-A
      '4006381333931', // EAN-13
      '7038010009457', // EAN-13, Norwegian prefix
      '10012345678902', // GTIN-14
    ]) {
      expectValidity(barcode, BarcodeValidity.validStandard);
    }
  });

  test('flags a standard length with a wrong check digit, still usable', () {
    for (final barcode in [
      '96385075',
      '036000291453',
      '4006381333932',
      '10012345678903',
    ]) {
      expectValidity(barcode, BarcodeValidity.invalidCheckDigit);
      expect(BarcodeValidator.isUsable(barcode), isTrue);
    }
  });

  test('accepts other numeric lengths from 4 to 32 as custom codes', () {
    for (final length in [4, 5, 7, 9, 11, 15, 32]) {
      expectValidity('1' * length, BarcodeValidity.validCustom);
    }
  });

  test('rejects non-digits and codes that are too short or long', () {
    for (final input in ['', '123', '1' * 33, 'abc123', '1234.5', '١٢٣٤']) {
      expectValidity(input, BarcodeValidity.invalidFormat);
      expect(BarcodeValidator.isUsable(input), isFalse);
    }
  });

  test('normalizes spaces and hyphens', () {
    final check = BarcodeValidator.validate(' 4 006381-333931\n');
    expect(check.barcode, '4006381333931');
    expect(check.validity, BarcodeValidity.validStandard);
  });
}
