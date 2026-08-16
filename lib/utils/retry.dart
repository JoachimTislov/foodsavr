import 'dart:async';

import 'package:logger/logger.dart';

/// Retries an [operation] a specified number of [retries] times.
///
/// If the operation fails, it will be retried after a [delay].
/// If all retries fail, the last exception will be rethrown.
Future<T> retry<T>(
  Future<T> Function() operation, {
  required Logger logger,
  Duration delay = const Duration(seconds: 2),
  int retries = 3,
  String? operationName,
}) async {
  for (int i = 0; i < retries; i++) {
    try {
      return await operation();
    } catch (e, s) {
      final attempt = i + 1;
      final name = operationName ?? 'Operation';
      logger.w('$name failed on attempt $attempt of $retries', error: e, stackTrace: s);
      if (i < retries - 1) {
        await Future.delayed(delay * attempt); // Increase delay for subsequent retries
      } else {
        logger.e('$name failed after $retries attempts', error: e, stackTrace: s);
        rethrow;
      }
    }
  }
  // This line is unreachable but required for the compiler.
  throw Exception('Retry mechanism failed unexpectedly.');
}
