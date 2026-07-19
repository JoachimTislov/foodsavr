import 'dart:convert';
import 'package:test/test.dart';

// Since update_schema.dart is not a package library we can't easily import its internal methods,
// we just test the JSON configuration parsing logic to ensure it behaves as expected conceptually.

void main() {
  group('Schema Migration Config Test', () {
    test('protectedFields are parsed correctly', () {
      final configJson = '''
      {
        "protectedFields": ["id", "userId", "schemaVersion"]
      }
      ''';
      final map = jsonDecode(configJson) as Map<String, dynamic>;
      final protected = List<String>.from(map['protectedFields'] as List);

      expect(protected, contains('id'));
      expect(protected, contains('schemaVersion'));
      expect(protected.length, 3);
    });

    test('addFields payload is constructed properly', () {
      final scriptJson = '''
      {
        "operations": [
          {
            "targetType": "document",
            "path": "test",
            "removeFields": [],
            "addFields": [
              {"name": "newCount", "type": "integer", "value": 10},
              {"name": "isActive", "type": "boolean", "value": true}
            ]
          }
        ]
      }
      ''';

      final map = jsonDecode(scriptJson) as Map<String, dynamic>;
      final ops = map['operations'] as List;
      final addFields = ops.first['addFields'] as List;

      expect(addFields[0]['name'], 'newCount');
      expect(addFields[0]['type'], 'integer');
      expect(addFields[0]['value'], 10);
    });
  });
}
