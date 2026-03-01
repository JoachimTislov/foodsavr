// Prints all translation keys from a JSON translation file in dot notation.
// Usage: dart run tool/print_translation_keys.dart [path]
// Default path: assets/translations/en-US.json

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void printKeys(Map<String, dynamic> map, [String prefix = '']) {
  for (final entry in map.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    if (entry.value is Map<String, dynamic>) {
      printKeys(entry.value as Map<String, dynamic>, key);
    } else {
      print('$key: ${entry.value}');
    }
  }
}

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'assets/translations/en-US.json';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $path');
    exit(1);
  }
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  printKeys(json);
}
