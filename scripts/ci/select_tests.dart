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
  'integration_test/auth_test.dart',
  'integration_test/firestore_crud_test.dart',
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

/// Transitive import closure of [entry] within lib/ and packages/.
Set<String> transitiveDeps(String entry) {
  final seen = <String>{};
  final queue = <String>[entry];
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!seen.add(file)) continue;
    final dir = File(file).parent.path;
    final importRe = RegExp(
      r'''(?:import|export|part)\s+'([^']+)''',
      multiLine: true,
    );
    for (final match in importRe.allMatches(File(file).readAsStringSync())) {
      final spec = match.group(1)!;
      if (spec.startsWith('dart:')) continue;
      String path;
      if (spec.startsWith('package:')) {
        final parts = spec.substring(7).split('/');
        path = parts.length > 2 && parts.first == 'foodsavr_core'
            ? 'packages/foodsavr_core/lib/${parts.skip(2).join('/')}'
            : 'lib/${parts.skip(1).join('/')}';
      } else {
        path = Uri.file('$dir/$spec').normalizePath().toFilePath();
        path = path.replaceAll(RegExp(r'/lib/lib/'), '/lib/');
      }
      if (File(path).existsSync() && !path.contains('/.dart_tool/')) {
        queue.add(path);
      }
    }
  }
  return seen;
}

void main(List<String> args) async {
  final forceAll = args.contains('--all');
  final baseRef = Platform.environment['BASE_REF'] ?? 'origin/main';

  // Escape hatch: manual or self-scope change forces the full suite.
  if (forceAll) {
    print('reason=forced full run');
    print('files=ALL');
    return;
  }

  final changed = (await git([
    'diff',
    '--name-only',
    baseRef.isNotEmpty ? '$baseRef...HEAD' : 'HEAD',
  ]))
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toSet();

  if (changed.any(selfScope.contains)) {
    print('reason=selection machinery changed; full run');
    print('files=ALL');
    return;
  }

  final changedDart = changed.where((c) => c.endsWith('.dart')).toSet();
  if (changedDart.isEmpty) {
    // Nothing code-related changed; still pin core workflows (cheap, vital).
    print('reason=no dart changes; core workflow pin only');
    print('files=${coreWorkflows.join(' ')}');
    return;
  }

  // Relational selection: every test whose transitive import closure
  // intersects the changed files is affected.
  final testFiles = [
    ...Directory('test').listSync(recursive: true).whereType<File>(),
    ...Directory('integration_test').listSync(recursive: true).whereType<File>(),
  ].map((f) => f.path).where((p) => p.endsWith('_test.dart')).toList();

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
  print('reason=relational selection + core workflow pin');
  print('files=${affected.join(' ')}');
  _writeDebug(jsonEncode({
    'changed': changed.toList(),
    'selected': affected.toList(),
  }));
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
