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
          final parts = spec.substring(7).split('/');
          path = parts.first == 'foodsavr_core'
              ? 'packages/foodsavr_core/lib/${parts.skip(2).join('/')}'
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
    tests = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('_test.dart'))
        .toList();
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

  if (toRun.isEmpty) {
    stdout.writeln('All selected tests are cached green.');
    // Codecov expects coverage for every run; produce a coverage report when
    // no test executed (an all-cached-green run creates none).
    final cov = File('coverage/lcov.info');
    if (!cov.existsSync()) {
      await _runFlutter([]);
      if (!cov.existsSync()) {
        cov.createSync(recursive: true);
      }
    }
    return;
  }

  final unit = toRun.where((t) => !t.startsWith('integration_test')).toList();
  final integration = toRun
      .where((t) => t.startsWith('integration_test'))
      .toList();
  int exitCode = 0;
  if (unit.isNotEmpty) {
    exitCode = await _runFlutter(unit);
  }
  if (exitCode == 0 && integration.isNotEmpty) {
    exitCode = await _runFlutter(integration);
  }
  final cov = File('coverage/lcov.info');
  if (!cov.existsSync()) {
    cov.createSync(recursive: true);
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
