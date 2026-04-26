import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

void main() async {
  final logger = Logger();

  final result = await Process.run('gh', [
    'pr',
    'view',
    '60',
    '--json',
    'reviews',
  ]);
  logger.i('--- reviews ---');
  if (result.stdout.toString().isNotEmpty) {
    try {
      final json = jsonDecode(result.stdout as String);
      logger.i(const JsonEncoder.withIndent('  ').convert(json));
    } catch (_) {
      logger.i(result.stdout);
    }
  }

  final result2 = await Process.run('gh', [
    'api',
    'repos/JoachimTislov/foodsavr/pulls/60/comments',
  ]);
  logger.i('--- comments ---');
  if (result2.stdout.toString().isNotEmpty) {
    try {
      final json = jsonDecode(result2.stdout as String);
      logger.i(const JsonEncoder.withIndent('  ').convert(json));
    } catch (_) {
      logger.i(result2.stdout);
    }
  }
  if (result2.stderr.toString().isNotEmpty) {
    logger.e('ERR: \${result2.stderr}');
  }
}
