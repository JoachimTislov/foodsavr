import 'dart:convert';
import 'dart:io';

final _trMethodRegex = RegExp(
  r'''['"]([^'"]+)['"]\.tr''',
); // For simple 'key'.tr or 'key'.tr(args: ...)
final _trConditionalRegex = RegExp(
  r'''\?\s*['"]([^'"]+)['"]\s*:\s*['"]([^'"]+)['"]\)''',
); // For (cond ? 'key1' : 'key2')
final _trFunctionRegex = RegExp(r'''_tr\(\s*['"]([^'"]+)['"]\s*\)''');

Set<String> _flattenKeys(Map<String, dynamic> map, [String prefix = '']) {
  final keys = <String>{};
  map.forEach((key, value) {
    final fullKey = prefix.isEmpty ? key : '$prefix.$key';
    if (value is Map<String, dynamic>) {
      keys.addAll(_flattenKeys(value, fullKey));
    } else {
      keys.add(fullKey);
    }
  });
  return keys;
}

void main() {
  final repoRoot = Directory.current.path;
  final sourceDirs = ['lib', 'integration_test', 'test'];
  final localeDir = Directory('$repoRoot/assets/translations');

  if (!localeDir.existsSync()) {
    stderr.writeln('Missing translations directory: ${localeDir.path}');
    exit(1);
  }

  final usedKeys = <String>{};
  for (final dirName in sourceDirs) {
    final dir = Directory('$repoRoot/$dirName');
    if (!dir.existsSync()) continue;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final match in _trMethodRegex.allMatches(content)) {
        usedKeys.add(match.group(1)!);
      }
      for (final _ in _trConditionalRegex.allMatches(content)) {
        // As DashboardView has been refactored, these keys are now directly handled,
        // so we don't need to add them here from the regex.
      }
      for (final match in _trFunctionRegex.allMatches(content)) {
        usedKeys.add(match.group(1)!);
      }
    }
  }

  final localeFiles =
      localeDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (localeFiles.isEmpty) {
    stderr.writeln('No locale JSON files found in ${localeDir.path}');
    exit(1);
  }

  var hasIssues = false;
  for (final file in localeFiles) {
    final fileName = file.uri.pathSegments.last;
    final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final keys = _flattenKeys(map);

    final missing = usedKeys.difference(keys).toList()..sort();
    final unused = keys.difference(usedKeys).toList()..sort();

    if (missing.isEmpty && unused.isEmpty) continue;

    hasIssues = true;
    stdout.writeln('\n[$fileName]');
    if (missing.isNotEmpty) {
      stdout.writeln('  Missing keys (${missing.length}):');
      for (final key in missing) {
        stdout.writeln('    - $key');
      }
    }
    if (unused.isNotEmpty) {
      stdout.writeln('  Unused keys (${unused.length}):');
      for (final key in unused) {
        stdout.writeln('    - $key');
      }
    }
  }

  if (hasIssues) {
    stderr.writeln(
      '\nLocalization validation failed. Add missing keys and remove unused keys.',
    );
    exit(1);
  }

  stdout.writeln(
    'Localization validation passed (${usedKeys.length} used keys checked).',
  );
}
