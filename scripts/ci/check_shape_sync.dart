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
  final anchors = <String>[];
  final entries = <Map<String, String>>[];
  for (final line in reg.split('\n')) {
    final id = RegExp(r'^\s*-\s+id:\s*(\S+)\s*$').firstMatch(line);
    if (id != null) {
      entries.add({'id': id.group(1)!});
      continue;
    }
    if (entries.isEmpty) continue;
    final anchor = RegExp(r'^\s+anchor:\s*(\S+)').firstMatch(line);
    if (anchor != null) {
      entries.last['anchor'] = anchor.group(1)!;
      if (anchor.group(1) != 'null') anchors.add(anchor.group(1)!);
    }
    final status = RegExp(r'^\s+status:\s*(\S+)').firstMatch(line);
    if (status != null) entries.last['status'] = status.group(1)!;
  }
  for (final entry in entries) {
    final status = entry['status'];
    final anchor = entry['anchor'];
    if (status == null) {
      fail('registry entry ${entry['id']} is missing a status');
      continue;
    }
    final requiresAnchor =
        status == 'built' || status == 'stub' || status == 'built-skeleton';
    if (requiresAnchor && (anchor == null || anchor == 'null')) {
      fail(
        'registry entry ${entry['id']} with status $status requires an '
        'anchor',
      );
      continue;
    }
    if (anchor == null || anchor == 'null') continue;
    if (!File('$repo/$anchor').existsSync() &&
        !Directory('$repo/$anchor').existsSync()) {
      fail('registry anchor missing in repo: $anchor');
    }
  }
  stdout.writeln(
    'anchors: ${anchors.length} checked, ${entries.length} registry entries',
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
    final title = schema['title'] as String? ?? '';
    final fields = _declaredFields(code, title);
    for (final p in props.where((p) => !fields.contains(p))) {
      fail(
        '${entity.uri.pathSegments.last}: property "$p" not found in code '
        'anchor $anchorPath',
      );
    }
    final modelName = title;
    for (final f in fields.where((f) => !props.contains(f))) {
      fail(
        '${entity.uri.pathSegments.last}: model field "$f" of $modelName '
        'missing from schema properties',
      );
    }
    stdout.writeln(
      'schema ${entity.uri.pathSegments.last}: ${props.length} properties '
      'checked against $anchorPath',
    );
  }
}

/// Field names declared by the anchored Dart class: constructor parameters
/// and plain `final` field declarations.
Set<String> _declaredFields(String code, String className) {
  final fields = <String>{};
  final enumValues = <String>{};
  for (final m in RegExp(
    r'enum\s+\w+\s*\{(.*?)\}',
    dotAll: true,
  ).allMatches(code)) {
    for (final v in m.group(1)!.split(',')) {
      final vm = RegExp(r'([a-zA-Z][a-zA-Z0-9]*)').allMatches(v.trim());
      if (vm.isNotEmpty) enumValues.add(vm.last.group(1)!);
    }
  }
  final ctor = RegExp(
    [r'(?:const\s+)?(?:factory\s+)?', className, r'\s*\((.*)'].join(),
    dotAll: true,
  );
  final ctorMatch = ctor.firstMatch(code);
  if (ctorMatch != null) {
    final body = ctorMatch.group(1)!;
    final end = _matchingParenIndex(body);
    if (end != null) {
      final params = body.substring(0, end);
      final cleaned = params
          .replaceAll(RegExp(r'//[^\n]*'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');
      for (final raw in cleaned.split(',')) {
        final param = raw.trim();
        final m = RegExp(r'([a-zA-Z][a-zA-Z0-9]*)$').firstMatch(param);
        if (m != null && !enumValues.contains(m.group(1)!)) {
          fields.add(m.group(1)!);
        }
      }
    }
  }
  for (final m in RegExp(
    r'final\s+[\w<>?,\s]+?\s+([a-z]\w*)\s*(?:=[^;]+)?;',
  ).allMatches(code)) {
    fields.add(m.group(1)!);
  }
  return fields;
}

/// Index of the `)` matching the `(` that opens [body], or null.
int? _matchingParenIndex(String body) {
  var depth = 1;
  for (var i = 0; i < body.length; i++) {
    if (body[i] == '(') {
      depth++;
    } else if (body[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
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
