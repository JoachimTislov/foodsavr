import 'package:test/test.dart';

import '../../scripts/locale/literal_text.dart';

void main() {
  List<String> literals(String source) =>
      findLiteralText(source).map((l) => l.text).toList();

  test('flags an untranslated Text literal', () {
    expect(literals("Text('Hello')"), ['Hello']);
  });

  test('flags interpolated messages in a SnackBar', () {
    final found = findLiteralText(
      "SnackBar(\n  content: Text('Failed to save: \$e'),\n)",
    ).single;
    expect(found.text, r'Failed to save: $e');
    expect(found.line, 2);
  });

  test('allows translated keys', () {
    expect(literals("Text('common.save'.tr())"), isEmpty);
    expect(literals("Text(\n  'a.b'\n      .tr(namedArgs: {}),\n)"), isEmpty);
    expect(literals("Text('a.b'.plural(2))"), isEmpty);
  });

  test('allows literals without letters and marked lines', () {
    expect(literals("Text(' · ')"), isEmpty);
    expect(literals(r"Text('${count}')"), isEmpty);
    expect(literals("Text('FoodSavr', // l10n-ignore\n)"), isEmpty);
  });
}
