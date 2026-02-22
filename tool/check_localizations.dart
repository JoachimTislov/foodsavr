import 'dart:convert';
import 'dart:io';

// Use comments to avoid extraction of test keys
// "auth.login".tr()
// "auth.extra".tr()
// "auth.missing".tr()
// "auth.new_key".tr()

final _trMethodRegex = RegExp(r'''['"]([^'"]+)['"]\.tr\(\)''');
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

Set<String> _extractUsedKeys(
  List<String> sourceDirs,
  List<String> ignorePaths,
) {
  final usedKeys = <String>{};
  final repoRoot = Directory.current.path;
  for (final dirName in sourceDirs) {
    final dir = Directory('$repoRoot/$dirName');
    if (!dir.existsSync()) continue;

    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      bool shouldIgnore = false;
      for (final ignorePath in ignorePaths) {
        if (entity.path.contains(ignorePath)) {
          shouldIgnore = true;
          break;
        }
      }
      if (shouldIgnore) continue;

      final content = entity.readAsStringSync();
      for (final match in _trMethodRegex.allMatches(content)) {
        usedKeys.add(match.group(1)!);
      }
      for (final match in _trFunctionRegex.allMatches(content)) {
        usedKeys.add(match.group(1)!);
      }
    }
  }
  return usedKeys;
}

List<File> _getLocaleFiles(Directory localeDir) {
  if (!localeDir.existsSync()) return [];
  return localeDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

void main() {
  final sourceDirs = ['lib', 'integration_test', 'test'];
  final ignorePaths = [
    'test/tool/',
  ]; // Ignore tool tests as they use dummy keys
  final repoRoot = Directory.current.path;
  final localeDir = Directory('$repoRoot/assets/translations');

  _handleValidate(sourceDirs, ignorePaths, localeDir);
}

void _handleValidate(
  List<String> sourceDirs,
  List<String> ignorePaths,
  Directory localeDir,
) {
  final usedKeys = _extractUsedKeys(sourceDirs, ignorePaths);
  final localeFiles = _getLocaleFiles(localeDir);

  if (localeFiles.isEmpty) {
    stderr.writeln('No locale JSON files found in ${localeDir.path}');
    exit(1);
  }

  var hasIssues = false;
  final allLocaleKeys = <String, Set<String>>{};
  final unionOfAllKeys = <String>{};

  for (final file in localeFiles) {
    final fileName = file.uri.pathSegments.last;
    final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final keys = _flattenKeys(map);
    allLocaleKeys[fileName] = keys;
    unionOfAllKeys.addAll(keys);

    final missing = usedKeys.difference(keys).toList()..sort();
    final unused = keys.difference(usedKeys).toList()..sort();

    if (missing.isNotEmpty || unused.isNotEmpty) {
      hasIssues = true;
      stdout.writeln('\n[$fileName]');
      if (missing.isNotEmpty) {
        stdout.writeln('  Missing keys from source (${missing.length}):');
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
  }

  // Structure consistency check
  stdout.writeln('\nChecking structure consistency across all locale files...');
  for (final entry in allLocaleKeys.entries) {
    final fileName = entry.key;
    final keys = entry.value;
    final missingFromOther = unionOfAllKeys.difference(keys).toList()..sort();
    if (missingFromOther.isNotEmpty) {
      hasIssues = true;
      stdout.writeln('  [$fileName] is missing keys present in other locales:');
      for (final key in missingFromOther) {
        stdout.writeln('    - $key');
      }
    }
  }

  if (hasIssues) {
    stderr.writeln(
      '\nLocalization validation failed. '
      'Please add missing keys and remove unused keys in your locale JSON files, '
      'or run the localization generator tool to update them.',
    );
    exit(1);
  } else {
    stdout.writeln(
      'Localization validation passed (${usedKeys.length} used keys checked).',
    );
  }
}
