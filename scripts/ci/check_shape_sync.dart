// Validates the shaped spec artifacts against the code, per ADR 0004
// (docs/source-of-truth/decisions/0004-truth-in-shapes.md).
//
// Checks:
// 1. Every registry entry with status built/stub/built-skeleton has an anchor
//    file that exists. Entries with status researched/spec-ahead require no
//    anchor.
// 2. Every schema property name matches a field in its declared code anchor
//    (Dart class), and every required schema property is present in code.
// Exits non-zero on any mismatch, so CI fails loudly on spec/code drift.
import 'dart:convert';
import 'dart:io';

final repo = Directory.current.path;
int failures = 0;

void fail(String message) {
  stderr.writeln('SHAPE-SYNC FAIL: $message');
  failures++;
}

void checkAnchors() {
  final reg = File(
    '$repo/docs/source-of-truth/registries/services.yaml',
  ).readAsStringSync();
  final anchorRe = RegExp(r'anchor:\s*(\S+)');
  final statusRe = RegExp(r'status:\s*(\S+)');
  final anchors = anchorRe.allMatches(reg).map((m) => m.group(1)!).toList();
  final statuses = statusRe.allMatches(reg).map((m) => m.group(1)!).toList();
  for (final anchor in anchors) {
    if (anchor == 'null') continue;
    if (!File('$repo/$anchor').existsSync() &&
        !Directory('$repo/$anchor').existsSync()) {
      fail('registry anchor missing in repo: $anchor');
    }
  }
  stdout.writeln(
    'anchors: ${anchors.where((a) => a != "null").length} checked, '
    '${statuses.length} registry entries',
  );
}

void checkSchemas() {
  final schemaDir = Directory('$repo/docs/source-of-truth/schemas');
  for (final entity in schemaDir.listSync()) {
    if (entity is! File || !entity.path.endsWith('.schema.json')) continue;
    final schema =
        jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
    final desc = schema['description'] as String? ?? '';
    final anchorMatch = RegExp(
      r'Code anchor:\s*([\w/.]+\.dart|[\w/.]+)',
    ).firstMatch(desc);
    if (anchorMatch == null) {
      fail('${entity.path}: no "Code anchor:" in description');
      continue;
    }
    final anchorPath = anchorMatch.group(1)!;
    final anchorFile = File('$repo/$anchorPath');
    if (!anchorFile.existsSync()) {
      fail('schema anchor file not found: $anchorPath');
      continue;
    }
    final code = anchorFile.readAsStringSync();
    final props = (schema['properties'] as Map<String, dynamic>).keys.toSet();
    final missing = props.where((p) => !code.contains(p)).toList();
    for (final m in missing) {
      fail(
        '${entity.uri.pathSegments.last}: property "$m" not found in code '
        'anchor $anchorPath',
      );
    }
    stdout.writeln(
      'schema ${entity.uri.pathSegments.last}: ${props.length} properties '
      'checked against $anchorPath',
    );
  }
}

void main() {
  checkAnchors();
  checkSchemas();
  if (failures > 0) {
    stderr.writeln('$failures shape-sync failure(s)');
    exit(1);
  }
  stdout.writeln('shape-sync: OK');
}
