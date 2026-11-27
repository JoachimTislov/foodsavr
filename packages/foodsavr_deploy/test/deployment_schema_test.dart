import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('schema limits Hosting site IDs to 6–30 characters', () {
    final schema = jsonDecode(
      File(
        '../../specs/schemas/deployment-instance.schema.json',
      ).readAsStringSync(),
    );
    final pattern = RegExp(
      schema[r'$defs']['hostingSiteId']['pattern'] as String,
    );
    for (final (length, valid) in [
      (5, false),
      (6, true),
      (30, true),
      (31, false),
    ]) {
      expect(
        pattern.hasMatch('a' * length),
        valid,
        reason: '$length characters',
      );
    }
  });
}
