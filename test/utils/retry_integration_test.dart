import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:foodsavr/utils/retry.dart';

class _RecordingLogger extends Logger {
  final List<String> messages = [];

  @override
  void w(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    messages.add('w:$message');
  }

  @override
  void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    messages.add('e:$message');
  }
}

void main() {
  test('returns value on first success without retries', () async {
    final logger = _RecordingLogger();
    var calls = 0;
    final result = await retry<int>(
      () async {
        calls++;
        return 42;
      },
      logger: logger,
      retries: 3,
      operationName: 'Op',
    );
    expect(result, 42);
    expect(calls, 1);
    expect(logger.messages, isEmpty);
  });

  test('retries and succeeds after transient failures', () async {
    final logger = _RecordingLogger();
    var calls = 0;
    final result = await retry<String>(
      () async {
        calls++;
        if (calls < 3) {
          throw Exception('transient');
        }
        return 'ok';
      },
      logger: logger,
      retries: 3,
      delay: const Duration(milliseconds: 1),
      operationName: 'Flaky',
    );
    expect(result, 'ok');
    expect(calls, 3);
    expect(logger.messages.where((m) => m.startsWith('w:')).length, 2);
  });

  test('rethrows the last error when all retries are exhausted', () async {
    final logger = _RecordingLogger();
    var calls = 0;
    await expectLater(
      retry<void>(
        () async {
          calls++;
          throw StateError('permanent');
        },
        logger: logger,
        retries: 2,
        delay: const Duration(milliseconds: 1),
        operationName: 'Broken',
      ),
      throwsA(isA<StateError>()),
    );
    expect(calls, 2);
    expect(
      logger.messages.any((m) => m.contains('failed after 2 attempts')),
      isTrue,
    );
  });
}
