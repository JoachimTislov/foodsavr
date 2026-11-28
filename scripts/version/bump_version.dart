// ignore_for_file: avoid_print

import 'dart:io';

import 'version_bump.dart';

/// Usage: `dart run scripts/version/bump_version.dart <major|minor|patch>`
/// [--dry-run] [--file=pubspec.yaml]
void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  var path = 'pubspec.yaml';
  final positional = <String>[];
  for (final arg in args) {
    if (arg == '--dry-run') continue;
    if (arg.startsWith('--file=')) {
      path = arg.substring('--file='.length);
    } else {
      positional.add(arg);
    }
  }
  if (positional.length != 1) {
    stderr.writeln('Usage: bump_version.dart <major|minor|patch> [--dry-run]');
    exit(64);
  }
  try {
    final file = File(path);
    final content = file.readAsStringSync();
    final current = parseVersion(content);
    final next = current.bump(parsePart(positional.single));
    if (!dryRun) file.writeAsStringSync(replaceVersion(content, next));
    print('${dryRun ? '[dry run] ' : ''}$current -> $next');
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exit(65);
  }
}
