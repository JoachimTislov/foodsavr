/// How a typed or scanned barcode reads.
enum BarcodeValidity {
  /// GTIN-8 (EAN-8), GTIN-12 (UPC-A), GTIN-13 (EAN-13) or GTIN-14 with a
  /// matching GS1 check digit.
  validStandard,

  /// A standard retail length whose check digit does not match. It is most
  /// likely a typo, but stores print such codes too, so it stays usable.
  invalidCheckDigit,

  /// A numeric store or internal code of any other accepted length.
  validCustom,

  /// Not a barcode: other characters than digits, or too short or long.
  invalidFormat,
}

typedef BarcodeCheck = ({String barcode, BarcodeValidity validity});

/// Pure barcode normalization and validation.
class BarcodeValidator {
  const BarcodeValidator._();

  static const minLength = 4;
  static const maxLength = 32;
  static const standardLengths = {8, 12, 13, 14};

  static final _separators = RegExp(r'[\s\-]');
  static final _digits = RegExp(r'^[0-9]+$');

  /// [input] without the spaces and hyphens people copy from labels.
  static String normalize(String input) => input.replaceAll(_separators, '');

  static BarcodeCheck validate(String input) {
    final barcode = normalize(input);
    return (barcode: barcode, validity: _validityOf(barcode));
  }

  /// Whether [input] can be saved as a product barcode.
  static bool isUsable(String input) =>
      validate(input).validity != BarcodeValidity.invalidFormat;

  static BarcodeValidity _validityOf(String barcode) {
    if (barcode.length < minLength ||
        barcode.length > maxLength ||
        !_digits.hasMatch(barcode)) {
      return BarcodeValidity.invalidFormat;
    }
    if (!standardLengths.contains(barcode.length)) {
      return BarcodeValidity.validCustom;
    }
    return _checkDigit(barcode.substring(0, barcode.length - 1)) ==
            int.parse(barcode[barcode.length - 1])
        ? BarcodeValidity.validStandard
        : BarcodeValidity.invalidCheckDigit;
  }

  /// GS1 Mod-10: from the right, the payload digits weigh 3, 1, 3, ...
  static int _checkDigit(String payload) {
    var sum = 0;
    for (var i = 0; i < payload.length; i++) {
      final digit = int.parse(payload[payload.length - 1 - i]);
      sum += i.isEven ? digit * 3 : digit;
    }
    return (10 - sum % 10) % 10;
  }
}
