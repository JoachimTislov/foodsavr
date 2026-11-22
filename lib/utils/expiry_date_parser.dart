/// Extracts expiry dates from OCR text.
///
/// Supports common printed formats on packaging:
/// - ISO:        2026-03-14, 2026.03.14, 2026/03/14
/// - European:   14.03.2026, 14/03/2026, 14-03-26, 14.03.26
/// - Month/year: 03/2027, 03.27, MAR 2027, MAI 2027 (last day of month)
/// - With words: EXP 14.03.2026, BEST BEFORE 14/03/2026, BB 14-03-2026
class ExpiryDateParser {
  static final _isoPattern = RegExp(
    r'\b(20\d{2})[-./](\d{1,2})[-./](\d{1,2})\b',
  );
  static final _europeanPattern = RegExp(
    r'\b(\d{1,2})[-./](\d{1,2})[-./](\d{2,4})\b',
  );
  // Exclude components of full dates, including invalid calendar dates.
  static final _numericMonthYearPattern = RegExp(
    r'(?<!\d[-./])\b(\d{1,2})[./](\d{4}|\d{2})\b(?![-./]\d)',
  );
  static const _monthNumbers = {
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'MAI': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'OKT': 10,
    'NOV': 11,
    'DEC': 12,
    'DES': 12,
  };
  static final _namedMonthYearPattern = RegExp(
    r'\b(' + _monthNumbers.keys.join('|') + r')\.?\s+(\d{4})\b(?![-./]\d)',
    caseSensitive: false,
  );
  static final _expiryHintPattern = RegExp(
    r'\b(?:exp|best\s*before|bb|use\s*by|minst|'
    r'best\s+før|holdbar\s+til|siste\s+forbruksdag|'
    r'bäst\s+före|bedst\s+før)\b',
    caseSensitive: false,
  );

  /// Returns the most plausible expiry date found in [text], or null.
  ///
  /// Prefers the first plausible date following an expiry hint on its line.
  /// Dates before today or in calendar years ten or more years ahead are ignored.
  static DateTime? findExpiryDate(String text) {
    DateTime? fallback;
    for (final line in text.split(RegExp(r'[\n\r]+'))) {
      final dates = _parseDates(
        line,
      ).where((candidate) => _isPlausible(candidate.date));
      final hint = _expiryHintPattern.firstMatch(line);
      ({int start, DateTime date})? hinted;
      for (final candidate in dates) {
        fallback ??= candidate.date;
        if (hint != null &&
            candidate.start >= hint.end &&
            (hinted == null || candidate.start < hinted.start)) {
          hinted = candidate;
        }
      }
      if (hinted != null) return hinted.date;
    }
    return fallback;
  }

  static List<({int start, DateTime date})> _parseDates(String line) {
    final dates = <({int start, DateTime date})>[];
    for (final match in _isoPattern.allMatches(line)) {
      final date = _build(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
      if (date != null) dates.add((start: match.start, date: date));
    }
    for (final match in _europeanPattern.allMatches(line)) {
      final date = _build(
        _parseYear(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
      if (date != null) dates.add((start: match.start, date: date));
    }
    for (final match in _numericMonthYearPattern.allMatches(line)) {
      final month = int.parse(match.group(1)!);
      if (month < 1 || month > 12) continue;
      final year = _parseYear(match.group(2)!);
      dates.add((start: match.start, date: DateTime(year, month + 1, 0)));
    }
    for (final match in _namedMonthYearPattern.allMatches(line)) {
      final month = _monthNumbers[match.group(1)!.toUpperCase()]!;
      final year = int.parse(match.group(2)!);
      dates.add((start: match.start, date: DateTime(year, month + 1, 0)));
    }
    return dates;
  }

  static int _parseYear(String value) {
    final year = int.parse(value);
    return year < 100 ? year + 2000 : year;
  }

  static bool _isPlausible(DateTime date) {
    final now = DateTime.now();
    return !date.isBefore(DateTime(now.year, now.month, now.day)) &&
        date.isBefore(DateTime(now.year + 10));
  }

  static DateTime? _build(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return DateTime(year, month, day);
  }
}
