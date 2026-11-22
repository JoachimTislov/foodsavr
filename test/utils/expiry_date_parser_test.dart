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
    final year = futureYear();
    final yy = (year % 100).toString().padLeft(2, '0');
    final date = ExpiryDateParser.findExpiryDate('BB 14-03-$yy');
    expect(date, DateTime(year, 3, 14));
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

  test('recognizes Norwegian expiry hints on labels with competing dates', () {
    final year = futureYear();
    final yy = (year % 100).toString().padLeft(2, '0');
    expect(
      ExpiryDateParser.findExpiryDate(
        'PROD $year-01-01 Best før 12.03.$year LOT $year-06-01',
      ),
      DateTime(year, 3, 12),
    );
    expect(
      ExpiryDateParser.findExpiryDate(
        'PROD 01.01.$year Siste forbruksdag: 05.12.$yy',
      ),
      DateTime(year, 12, 5),
    );
  });

  test('parses numeric and named month/year dates at month end', () {
    final year = futureYear();
    final yy = (year % 100).toString().padLeft(2, '0');
    for (final input in ['03/$year', '03.$yy', 'MAR $year']) {
      expect(ExpiryDateParser.findExpiryDate(input), DateTime(year, 3, 31));
    }
    expect(ExpiryDateParser.findExpiryDate('MAI $year'), DateTime(year, 5, 31));
    final leapYear = ((now.year ~/ 4) + 1) * 4;
    expect(
      ExpiryDateParser.findExpiryDate('02/$leapYear'),
      DateTime(leapYear, 2, 29),
    );
  });

  test('prefers a hinted month/year over a production date', () {
    final year = futureYear();
    expect(
      ExpiryDateParser.findExpiryDate(
        'PROD 01.01.$year Holdbar til: MAI $year',
      ),
      DateTime(year, 5, 31),
    );
  });

  test('rejects invalid or implausible month/year dates', () {
    for (final input in [
      '13/${futureYear()}',
      '31.02.${futureYear()}',
      '02/2020',
      'EXP MAI ${now.year + 20}',
    ]) {
      expect(ExpiryDateParser.findExpiryDate(input), isNull, reason: input);
    }
  });

  test('returns null for text without dates', () {
    expect(ExpiryDateParser.findExpiryDate('No dates here'), isNull);
    expect(ExpiryDateParser.findExpiryDate(''), isNull);
  });
}
