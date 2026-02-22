import 'dart:convert';
import 'dart:io';

final _trMethodRegex = RegExp(r'''['"]([^'"]+)['"]\.tr\(''');
final _trFunctionRegex = RegExp(r'''\b_?tr\(\s*['"]([^'"]+)['"]''');

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

Map<String, dynamic> _unflatten(
  Set<String> keys, {
  Map<String, dynamic>? existing,
  String Function(String)? stubGenerator,
}) {
  final root = existing ?? <String, dynamic>{};
  for (final key in keys) {
    final parts = key.split('.');
    var current = root;
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (i == parts.length - 1) {
        if (!current.containsKey(part)) {
          current[part] = stubGenerator?.call(key) ?? '[STUB] $key';
        }
      } else {
        final next = current.putIfAbsent(part, () => <String, dynamic>{});
        if (next is! Map<String, dynamic>) {
          final path = parts.sublist(0, i + 1).join('.');
          stderr.writeln('WARNING: Key path conflict at "$path". '
              'Replacing existing leaf value "$next" with a nested structure.');
          current[part] = <String, dynamic>{};
          current = current[part] as Map<String, dynamic>;
        } else {
          current = next;
        }
      }
    }
  }
  return root;
}

void _sortMap(Map<String, dynamic> m) {
  final keys = m.keys.toList()..sort();
  final sorted = <String, dynamic>{};
  for (final k in keys) {
    final v = m[k];
    if (v is Map<String, dynamic>) {
      _sortMap(v);
    }
    sorted[k] = v;
  }
  m.clear();
  m.addAll(sorted);
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

  _handleGenerate(sourceDirs, ignorePaths, localeDir);
}

void _handleGenerate(
  List<String> sourceDirs,
  List<String> ignorePaths,
  Directory localeDir,
) {
  stdout.writeln('--- Generating Localization Stubs ---');
  final usedKeys = _extractUsedKeys(sourceDirs, ignorePaths);
  final localeFiles = _getLocaleFiles(localeDir);

  if (localeFiles.isEmpty) {
    stderr.writeln('No locale JSON files found in ${localeDir.path}');
    exit(1);
  }

  final allLocaleKeys = <String, Set<String>>{};
  final unionOfAllKeys = <String>{};
  unionOfAllKeys.addAll(usedKeys);

  for (final file in localeFiles) {
    final fileName = file.uri.pathSegments.last;
    final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final keys = _flattenKeys(map);
    allLocaleKeys[fileName] = keys;
    unionOfAllKeys.addAll(keys);
  }

  final encoder = JsonEncoder.withIndent('    ');

  for (final file in localeFiles) {
    final fileName = file.uri.pathSegments.last;
    final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final keys = allLocaleKeys[fileName]!;
    final missing = unionOfAllKeys.difference(keys);

    if (missing.isEmpty) {
      stdout.writeln('[$fileName] No missing keys. Sorting existing keys...');
      _sortMap(map);
      file.writeAsStringSync(encoder.convert(map));
      continue;
    }

    stdout.writeln('[$fileName] Adding ${missing.length} stubs and sorting...');
    final updatedMap = _unflatten(missing, existing: map);
    _sortMap(updatedMap);

    file.writeAsStringSync(encoder.convert(updatedMap));
    stdout.writeln('[$fileName] Updated.');
  }
}
