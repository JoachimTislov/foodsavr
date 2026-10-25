// Selects the tests to run for a CI trigger, per ADR 0002
// (docs/source-of-truth/decisions/0002-intent-gated-specs-optimized-verification.md):
// hash-based caching + relational (import) selection + core-workflow pinning.
//
// Inputs (env or defaults):
//   BASE_REF  - git ref to diff against (default: origin/main)
// Outputs (written to $GITHUB_OUTPUT of the calling step):
//   files     - space-separated selected test paths ("ALL" forces full suite)
//   reason    - human-readable selection reason
import 'dart:convert';
import 'dart:io';

const coreWorkflows = <String>[
  'test/services/auth_service_test.dart',
  'test/router_auth_flow_test.dart',
  'test/services/receipt_ingestion_service_test.dart',
  'test/services/collection_service_integration_test.dart',
  'test/models/product_model_test.dart',
];

const selfScope = <String>[
  'scripts/ci/select_tests.dart',
  '.github/workflows/ci-checks.yml',
  'pubspec.yaml',
  'pubspec.lock',
  'analysis_options.yaml',
];

Future<String> git(List<String> args) async {
  final res = await Process.run('git', args);
  if (res.exitCode != 0) {
    stderr.writeln('git ${args.join(' ')} failed: ${res.stderr}');
    exit(2);
  }
  return (res.stdout as String).trim();
}

/// Transitive dependency closure of [entry] within lib/ and packages/.
///
/// Deleted files stay in the closure, so tests that still import a deleted
/// file remain selected.
Set<String> transitiveDeps(String entry) {
  final seen = <String>{};
  final queue = <String>[entry];
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!seen.add(file)) continue;
    if (!File(file).existsSync()) continue;
    final dir = File(file).parent.path;
    final importRe = RegExp(
      r"""(?:import|export|part)\s+['"]([^'"]+)['"]""",
      multiLine: true,
    );
    for (final match in importRe.allMatches(File(file).readAsStringSync())) {
      for (final path in _resolveSpec(match.group(0)!.trim(), dir)) {
        if (!path.contains('/.dart_tool/')) {
          queue.add(path);
        }
      }
    }
  }
  return seen;
}

/// Resolves one import/export/part spec (including every URI a conditional
/// `export ... if (...) ...` can select) to repo paths.
List<String> _resolveSpec(String spec, String dir) {
  if (spec.startsWith('dart:')) return const [];
  final specs = <String>[spec];
  final results = <String>[];
  final condRe = RegExp(
    r"""['"]([^'"]+)['"]\s+if\s*\(.*?\)\s*['"]([^'"]+)['"]""",
  );
  while (specs.isNotEmpty) {
    final s = specs.removeLast();
    final cond = condRe.firstMatch(s);
    if (cond != null) {
      specs
        ..add(cond.group(1)!)
        ..add(cond.group(2)!);
      continue;
    }
    String path;
    if (s.startsWith('package:')) {
      final parts = s.substring(7).split('/');
      path = parts.first == 'foodsavr_core'
          ? 'packages/foodsavr_core/lib/${parts.skip(2).join('/')}'
          : 'lib/${parts.skip(1).join('/')}';
    } else {
      path = Uri.file('$dir/$s').normalizePath().toFilePath();
      path = path.replaceAll(RegExp(r'/lib/lib/'), '/lib/');
    }
    results.add(path);
  }
  return results;
}

void main(List<String> args) async {
  final forceAll = args.contains('--all');
  final baseRef = Platform.environment['BASE_REF'] ?? 'origin/main';

  // Escape hatch: manual or self-scope change forces the full suite.
  if (forceAll) {
    stdout.writeln('reason=forced full run');
    stdout.writeln('files=ALL');
    return;
  }

  final changed = (await git([
    'diff',
    '--name-only',
    baseRef.isNotEmpty ? '$baseRef...HEAD' : 'HEAD',
  ])).split('\n').where((l) => l.trim().isNotEmpty).toSet();

  if (changed.any(selfScope.contains)) {
    stdout.writeln('reason=selection machinery changed; full run');
    stdout.writeln('files=ALL');
    return;
  }

  final changedDart = changed.where((c) => c.endsWith('.dart')).toSet();
  if (changedDart.isEmpty) {
    // Nothing code-related changed; still pin core workflows (cheap, vital).
    stdout.writeln('reason=no dart changes; core workflow pin only');
    stdout.writeln('files=${coreWorkflows.join(' ')}');
    return;
  }

  // Relational selection: every test whose transitive import closure
  // intersects the changed files is affected.
  final testFiles = Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path)
      .where((p) => p.endsWith('_test.dart'))
      .toList();

  final affected = <String>{...coreWorkflows};
  for (final test in testFiles) {
    final norm = test.startsWith('./') ? test.substring(2) : test;
    if (coreWorkflows.contains(norm)) continue;
    if (transitiveDeps(norm).any(changedDart.contains)) {
      affected.add(norm);
    }
  }

  // Spec/infra changes (docs, workflows other than self-scope) don't expand
  // the slice; core workflows still run.
  stdout.writeln('reason=relational selection + core workflow pin');
  stdout.writeln('files=${affected.join(' ')}');
  _writeDebug(
    jsonEncode({'changed': changed.toList(), 'selected': affected.toList()}),
  );
}

void _writeDebug(String json) {
  final path = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (path != null) {
    File(path).writeAsStringSync(
      '### Test selection (ADR 0002)\n```json\n$json\n```\n',
      mode: FileMode.append,
    );
  }
}
