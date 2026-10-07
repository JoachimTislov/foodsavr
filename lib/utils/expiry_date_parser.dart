/// Extracts expiry dates from OCR text.
///
/// Supports common printed formats on packaging:
/// - ISO:        2026-03-14, 2026.03.14, 2026/03/14
/// - European:   14.03.2026, 14/03/2026, 14-03-26, 14.03.26
/// - With words: EXP 14.03.2026, BEST BEFORE 14/03/2026, BB 14-03-2026
class ExpiryDateParser {
  static final _isoPattern = RegExp(
    r'\b(20\d{2})[-./](\d{1,2})[-./](\d{1,2})\b',
  );
  static final _europeanPattern = RegExp(
    r'\b(\d{1,2})[-./](\d{1,2})[-./](\d{2,4})\b',
  );
  static final _expiryHintPattern = RegExp(
    r'(?:\bexp|best\s*before|\bbb\b|use\s*by|\bminst)\b',
    caseSensitive: false,
  );

  /// Returns the most plausible expiry date found in [text], or null.
  ///
  /// Lines containing expiry hints (EXP, BEST BEFORE, ...) are preferred.
  /// Dates in the past are ignored; dates more than ten years ahead are
  /// ignored as misreads.
  static DateTime? findExpiryDate(String text) {
    if (text.isEmpty) return null;
    final candidates = <DateTime>[];
    DateTime? hinted;
    final lines = text.split(RegExp(r'[\n\r]+'));
    for (final line in lines) {
      final dates = _parseDates(line);
      candidates.addAll(dates);
      final expDate = _dateAfterExpiryHint(line, dates);
      if (expDate != null && _isPlausible(expDate)) return expDate;
      hinted ??= expDate;
    }
    if (hinted != null && _isPlausible(hinted)) return hinted;
    for (final candidate in candidates) {
      if (_isPlausible(candidate)) return candidate;
    }
    return null;
  }

  static List<DateTime> _parseDates(String line) {
    final dates = <DateTime>[];
    for (final match in _isoPattern.allMatches(line)) {
      final date = _build(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
      if (date != null) dates.add(date);
    }
    for (final match in _europeanPattern.allMatches(line)) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      var year = int.parse(match.group(3)!);
      if (year < 100) year += 2000;
      final date = _build(year, month, day);
      if (date != null) dates.add(date);
    }
    return dates;
  }

  static DateTime? _dateAfterExpiryHint(String line, List<DateTime> dates) {
    if (dates.isEmpty) return null;
    for (final hint in _expiryHintPattern.allMatches(line)) {
      final hintEnd = hint.end;
      for (final match in _isoPattern.allMatches(line)) {
        if (match.start >= hintEnd) {
          final date = _build(
            int.parse(match.group(1)!),
            int.parse(match.group(2)!),
            int.parse(match.group(3)!),
          );
          if (date != null) return date;
        }
      }
      for (final match in _europeanPattern.allMatches(line)) {
        if (match.start >= hintEnd) {
          final day = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          var year = int.parse(match.group(3)!);
          if (year < 100) year += 2000;
          final date = _build(year, month, day);
          if (date != null) return date;
        }
      }
    }
    return null;
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
