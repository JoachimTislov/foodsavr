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

  test('ignores implausible dates on lines with expiry hints', () {
    expect(ExpiryDateParser.findExpiryDate('BEST BEFORE 01.01.2020'), isNull);
    expect(
      ExpiryDateParser.findExpiryDate('EXP 01.01.${DateTime.now().year + 20}'),
      isNull,
    );
  });

  test('prefers EXP date over MFG date on the same line', () {
    final mfgYear = DateTime.now().year + 1;
    final text = 'MFG $mfgYear-01-01 EXP $mfgYear-03-14';
    final date = ExpiryDateParser.findExpiryDate(text);
    expect(date, DateTime(mfgYear, 3, 14));
  });

  test('prefers the first date following the hint over later ones', () {
    final year = DateTime.now().year + 1;
    final text = 'BEST BEFORE 15.06.$year 01.01.$year';
    final date = ExpiryDateParser.findExpiryDate(text);
    expect(date, DateTime(year, 6, 15));
  });

  test('falls back to hinted date from an earlier line', () {
    final year = DateTime.now().year + 1;
    final text = 'EXP 15.06.$year\nLOT 123';
    final date = ExpiryDateParser.findExpiryDate(text);
    expect(date, DateTime(year, 6, 15));
  });

  test('ignores hinted date that is implausible', () {
    final year = DateTime.now().year + 1;
    final text = 'EXP 01.01.2020 15.06.$year';
    final date = ExpiryDateParser.findExpiryDate(text);
    expect(date, DateTime(year, 6, 15));
  });

  test('returns null for text without dates', () {
    expect(ExpiryDateParser.findExpiryDate('No dates here'), isNull);
    expect(ExpiryDateParser.findExpiryDate(''), isNull);
  });
}
