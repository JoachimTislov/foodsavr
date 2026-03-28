import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

final _trMethodRegex = RegExp(r'''['"]([^'"]+)['"]\.tr(?:With)?\s*\(''');
final _trFunctionRegex = RegExp(r'''(?:\b|_)tr\s*\(\s*['"]([^'"]+)['"]''');

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

void _removeKey(Map<String, dynamic> map, List<String> parts) {
  if (parts.isEmpty) return;
  final key = parts.first;
  if (parts.length == 1) {
    map.remove(key);
  } else {
    final next = map[key];
    if (next is Map<String, dynamic>) {
      _removeKey(next, parts.sublist(1));
      if (next.isEmpty) {
        map.remove(key);
      }
    }
  }
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

      final relativePath = p.relative(entity.path, from: repoRoot);
      bool shouldIgnore = false;
      for (final ignorePath in ignorePaths) {
        if (p.isWithin(ignorePath, relativePath) ||
            p.equals(ignorePath, relativePath)) {
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
  final ignorePaths = [p.normalize('test/tool/')];
  final repoRoot = Directory.current.path;
  final localeDir = Directory('$repoRoot/assets/translations');

  _handleRemoveUnused(sourceDirs, ignorePaths, localeDir);
}

void _handleRemoveUnused(
  List<String> sourceDirs,
  List<String> ignorePaths,
  Directory localeDir,
) {
  stdout.writeln('--- Removing Unused Localization Keys ---');
  final usedKeys = _extractUsedKeys(sourceDirs, ignorePaths);
  final localeFiles = _getLocaleFiles(localeDir);

  if (localeFiles.isEmpty) {
    stderr.writeln('No locale JSON files found in ${localeDir.path}');
    exit(1);
  }

  final encoder = JsonEncoder.withIndent('    ');

  for (final file in localeFiles) {
    final fileName = file.uri.pathSegments.last;
    final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final keys = _flattenKeys(map);
    final unused = keys.difference(usedKeys);

    if (unused.isEmpty) {
      stdout.writeln('[$fileName] No unused keys found.');
      continue;
    }

    stdout.writeln('[$fileName] Removing ${unused.length} unused keys...');
    for (final key in unused) {
      _removeKey(map, key.split('.'));
    }

    _sortMap(map);
    file.writeAsStringSync(encoder.convert(map));
    stdout.writeln('[$fileName] Updated.');
  }
}
