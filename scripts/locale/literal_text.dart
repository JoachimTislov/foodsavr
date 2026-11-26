/// Directories whose `Text(...)` and `SnackBar` contents must be localized.
const literalTextDirs = ['lib/views', 'lib/widgets', 'lib/features'];

/// Marks a line whose literal is intentionally not translated.
const literalTextIgnore = 'l10n-ignore';

// `Text(` or `Text.rich(TextSpan(text:`, then a string literal.
final _textLiteral = RegExp(
  r'''\b(?:Text|TextSpan)\(\s*(?:text:\s*)?(['"])((?:\\.|(?!\1).)*)\1''',
);
final _translated = RegExp(r'''^\s*\.(?:tr|trWith|plural)\b''');
final _letter = RegExp(r'[A-Za-zÀ-ɏ]');

/// A user-visible string literal that bypasses the translations.
class LiteralText {
  final int line;
  final String text;

  const LiteralText(this.line, this.text);

  @override
  String toString() => '$line: $text';
}

/// Finds `Text('...')` literals in [source] that are not passed through
/// `.tr()`, `.trWith()`, or `.plural()`.
///
/// Literals without letters (separators, symbols) are allowed, as are lines
/// marked with `// l10n-ignore`.
Iterable<LiteralText> findLiteralText(String source) sync* {
  for (final match in _textLiteral.allMatches(source)) {
    final text = match.group(2)!;
    final withoutInterpolation = text.replaceAll(
      RegExp(r'\$\{[^}]*\}|\$\w+'),
      '',
    );
    if (!_letter.hasMatch(withoutInterpolation)) continue;
    if (_translated.hasMatch(source.substring(match.end))) continue;

    final lineStart = source.lastIndexOf('\n', match.start) + 1;
    var lineEnd = source.indexOf('\n', match.end);
    if (lineEnd == -1) lineEnd = source.length;
    if (source.substring(lineStart, lineEnd).contains(literalTextIgnore)) {
      continue;
    }
    final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
    yield LiteralText(line, text);
  }
}
