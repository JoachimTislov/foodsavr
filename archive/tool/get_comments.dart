import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

Future<void> _runAndLog(
  Logger logger,
  String section,
  List<String> args,
) async {
  final result = await Process.run('gh', args);
  logger.i('--- $section ---');
  final out = result.stdout.toString();
  if (out.isNotEmpty) {
    try {
      logger.i(const JsonEncoder.withIndent('  ').convert(jsonDecode(out)));
    } catch (_) {
      logger.i(out);
    }
  }
  final err = result.stderr.toString();
  if (err.isNotEmpty) {
    logger.e('ERR (exit ${result.exitCode}): $err');
  }
}

void main(List<String> args) async {
  final logger = Logger();
  final pr = args.isNotEmpty ? args.first : '60';
  await _runAndLog(logger, 'reviews', ['pr', 'view', pr, '--json', 'reviews']);
  await _runAndLog(logger, 'comments', [
    'api',
    'repos/JoachimTislov/foodsavr/pulls/$pr/comments',
  ]);
}
