// Test runner implementing ADR 0002's hash-based caching:
// runs the selected slice (SELECTED_FILES or ALL when FORCE_ALL), skipping
// any test whose per-test input hash matches a previously green run.
// Hash = test file + transitive imports (via select_tests.dart closure) +
// flutter/dart SDK version, stored in .test-hashes/<sanitized>.json.
import 'dart:convert';
import 'dart:io';

String get selected => Platform.environment['SELECTED_FILES'] ?? 'ALL';
bool get forceAll => Platform.environment['FORCE_ALL'] == 'true';
const hashDir = '.test-hashes';
const corePackageDir = 'packages/foodsavr_core';
const testRoots = <String>['test', '$corePackageDir/test'];
const corePackageInputs = <String>[
  '$corePackageDir/pubspec.yaml',
  '$corePackageDir/analysis_options.yaml',
];

Set<String> transitiveDeps(String entry) {
  final seen = <String>{};
  final queue = <String>[entry];
  final importRe = RegExp(r"""(?:import|export|part)\s+['"]([^'"]+)['"]""");
  final condRe = RegExp(
    r"""^\s*['"]([^'"]+)['"]\s+if\s*\(.*?\)\s*['"]([^'"]+)['"]""",
  );
  while (queue.isNotEmpty) {
    final file = queue.removeLast();
    if (!seen.add(file)) continue;
    if (!File(file).existsSync()) continue;
    for (final match in importRe.allMatches(File(file).readAsStringSync())) {
      final specs = <String>[match.group(1)!];
      while (specs.isNotEmpty) {
        final spec = specs.removeLast();
        if (spec.startsWith('dart:')) continue;
        final cond = condRe.firstMatch(spec);
        if (cond != null) {
          specs
            ..add(cond.group(1)!)
            ..add(cond.group(2)!);
          continue;
        }
        String path;
        if (spec.startsWith('package:')) {
          final parts = spec.substring('package:'.length).split('/');
          path = parts.first == 'foodsavr_core'
              ? 'packages/foodsavr_core/lib/${parts.skip(1).join('/')}'
              : 'lib/${parts.skip(1).join('/')}';
        } else {
          final base = File(file).parent.path;
          final candidate = Uri.file(
            '$base/$spec',
          ).normalizePath().toFilePath();
          path = File(candidate).existsSync() ? candidate : '';
        }
        if (path.isNotEmpty &&
            File(path).existsSync() &&
            !path.contains('.dart_tool')) {
          queue.add(path);
        }
      }
    }
  }
  return seen;
}

Future<String> hashOf(String test) async {
  final deps = transitiveDeps(test).toList()..sort();
  // Package tests also depend on the package manifest and lints, which select
  // them (select_tests.dart) and must therefore invalidate cached-green runs.
  if (test.startsWith('$corePackageDir/')) {
    for (final input in corePackageInputs) {
      if (File(input).existsSync()) deps.add(input);
    }
  }
  final sink = StringBuffer();
  for (final dep in deps) {
    sink.write(dep);
    sink.write(await File(dep).readAsString());
  }
  sink.write(Platform.version);
  final digest = await _sha256(sink.toString());
  return digest;
}

Future<String> _sha256(String data) async {
  final tmp = File('.tmp-hash-input');
  await tmp.writeAsString(data, flush: true);
  final res = await Process.run('sha256sum', ['.tmp-hash-input']);
  tmp.deleteSync();
  return (res.stdout as String).split(' ').first.trim();
}

Future<void> main() async {
  Directory(hashDir).createSync(recursive: true);
  final isAll = forceAll || selected == 'ALL';
  List<String> tests;
  if (isAll) {
    tests = [
      for (final root in testRoots)
        if (Directory(root).existsSync())
          ...Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .map((f) => f.path)
              .where((p) => p.endsWith('_test.dart')),
    ];
  } else {
    tests = selected.split(' ').where((t) => t.trim().isNotEmpty).toList();
  }

  final toRun = <String>[];
  final cachedGreen = <String>[];
  for (final test in tests) {
    final norm = test.startsWith('./') ? test.substring(2) : test;
    if (!File(norm).existsSync()) {
      stderr.writeln('selected test not found: $norm');
      exit(2);
    }
    final hash = await hashOf(norm);
    final marker = File('$hashDir/$hash.green');
    if (!isAll && marker.existsSync()) {
      cachedGreen.add(norm);
    } else {
      toRun.add(norm);
    }
  }

  stdout.writeln(
    'ADR 0002 runner: ${toRun.length} to run, '
    '${cachedGreen.length} cached-green skipped, '
    '${tests.length} total selected.',
  );

  int exitCode = 0;
  if (toRun.isEmpty) {
    stdout.writeln('All selected tests are cached green.');
    stdout.writeln(
      'No coverage report generated; Codecov upload will be skipped.',
    );
    return;
  }

  final core = toRun.where((t) => t.startsWith('$corePackageDir/')).toList();
  final rest = toRun.where((t) => !core.contains(t)).toList();
  final unit = rest.where((t) => !t.startsWith('integration_test')).toList();
  final integration = rest
      .where((t) => t.startsWith('integration_test'))
      .toList();
  if (core.isNotEmpty) {
    exitCode = await _runCorePackage(core);
  }
  if (exitCode == 0 && unit.isNotEmpty) {
    exitCode = await _runFlutter(unit);
  }
  if (exitCode == 0 && integration.isNotEmpty) {
    exitCode = await _runFlutter(integration);
  }
  if (exitCode != 0) {
    exit(exitCode);
  }
  for (final test in toRun) {
    final hash = await hashOf(test);
    File('$hashDir/$hash.green').writeAsStringSync(
      jsonEncode({
        'test': test,
        'sha': hash,
        'ts': DateTime.now().toIso8601String(),
      }),
    );
  }
}

Future<int> _runFlutter(List<String> tests) async {
  final res = await Process.run('flutter', [
    'test',
    '--no-pub',
    '--coverage',
    ...tests,
  ], runInShell: true);
  stdout.write(res.stdout);
  stderr.write(res.stderr);
  return res.exitCode;
}

/// Runs the foodsavr_core package tests with `dart test` inside the package,
/// which is a standalone pure Dart package with its own dependencies.
Future<int> _runCorePackage(List<String> tests) async {
  final relative = [
    for (final t in tests) t.substring('$corePackageDir/'.length),
  ];
  var res = await Process.run(
    'dart',
    ['pub', 'get'],
    workingDirectory: corePackageDir,
    runInShell: true,
  );
  if (res.exitCode == 0) {
    res = await Process.run(
      'dart',
      ['test', ...relative],
      workingDirectory: corePackageDir,
      runInShell: true,
    );
  }
  stdout.write(res.stdout);
  stderr.write(res.stderr);
  return res.exitCode;
}
