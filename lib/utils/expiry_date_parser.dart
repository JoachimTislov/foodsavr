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

    final lines = text.split(RegExp(r'[\n\r]+'));
    for (final line in lines) {
      final hasHint = _expiryHintPattern.hasMatch(line);
      final iso = _parseIso(line);
      if (iso != null) {
        candidates.add(iso);
        if (hasHint) return iso;
        continue;
      }
      final european = _parseEuropean(line);
      if (european != null) {
        candidates.add(european);
        if (hasHint) return european;
      }
    }

    for (final candidate in candidates) {
      if (_isPlausible(candidate)) return candidate;
    }
    return null;
  }

  static bool _isPlausible(DateTime date) {
    final now = DateTime.now();
    return !date.isBefore(DateTime(now.year, now.month, now.day)) &&
        date.isBefore(DateTime(now.year + 10));
  }

  static DateTime? _parseIso(String line) {
    final match = _isoPattern.firstMatch(line);
    if (match == null) return null;
    return _build(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static DateTime? _parseEuropean(String line) {
    final match = _europeanPattern.firstMatch(line);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    return _build(year, month, day);
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
