final _pluralMethod = RegExp(r'''['"]([^'"]+)['"]\s*\.plural\s*\(''');
final _pluralFunction = RegExp(r'''\bplural\s*\(\s*['"]([^'"]+)['"]''');

/// Finds the translation forms required by literal plural calls.
Iterable<String> pluralTranslationKeys(String source) sync* {
  for (final match in [
    ..._pluralMethod.allMatches(source),
    ..._pluralFunction.allMatches(source),
  ]) {
    final key = match.group(1)!;
    for (final form in const ['zero', 'one', 'other']) {
      yield '$key.$form';
    }
  }
}
