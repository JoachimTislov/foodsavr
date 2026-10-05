import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/expiry_date_parser.dart';

void main() {
  final now = DateTime.now();
  int futureYear() => now.year + 1;

  test('parses ISO dates', () {
    final year = futureYear();
    final date = ExpiryDateParser.findExpiryDate(
      'Some text $year-03-14 more text',
    );
    expect(date, DateTime(year, 3, 14));
  });

  test('parses European day-first dates', () {
    final date = ExpiryDateParser.findExpiryDate('14.03.${futureYear()}');
    expect(date, DateTime(futureYear(), 3, 14));
  });

  test('parses two-digit years', () {
    final date = ExpiryDateParser.findExpiryDate('BB 14-03-30');
    expect(date, DateTime(2030, 3, 14));
  });

  test('prefers lines with expiry hints', () {
    final year = futureYear();
    final text =
        'LOT 1234\n01.01.$year\n'
        'BEST BEFORE: 15.06.$year';
    final date = ExpiryDateParser.findExpiryDate(text);
    expect(date, DateTime(year, 6, 15));
  });

  test('ignores impossible dates', () {
    expect(ExpiryDateParser.findExpiryDate('32.13.${futureYear()}'), isNull);
  });

  test('ignores past dates', () {
    expect(ExpiryDateParser.findExpiryDate('01.01.2020'), isNull);
  });

  test('ignores dates too far in the future', () {
    expect(ExpiryDateParser.findExpiryDate('01.01.${now.year + 20}'), isNull);
  });

  test('returns null for text without dates', () {
    expect(ExpiryDateParser.findExpiryDate('No dates here'), isNull);
    expect(ExpiryDateParser.findExpiryDate(''), isNull);
  });
}
