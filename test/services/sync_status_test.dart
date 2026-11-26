import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/sync_status.dart';
import 'package:logger/logger.dart';

void main() {
  SyncStatus status() => SyncStatus.withTimeout(
    Logger(level: Level.off),
    const Duration(milliseconds: 10),
  );

  test('an unacknowledged write stays pending until the server acks', () async {
    final sync = status();
    final ack = Completer<void>();

    await sync.queue(() => ack.future);
    expect(sync.pendingWrites, 1);

    ack.complete();
    await pumpEventQueue();
    expect(sync.pendingWrites, 0);
  });

  test('an error before the timeout is rethrown', () async {
    final sync = status();

    await expectLater(
      sync.queue(() async => throw StateError('denied')),
      throwsStateError,
    );
    await pumpEventQueue();
    expect(sync.pendingWrites, 0);
  });

  test('a rejection after the timeout clears the pending write', () async {
    final sync = status();
    final ack = Completer<void>();

    await sync.queue(() => ack.future);
    ack.completeError(StateError('denied'));
    await pumpEventQueue();
    expect(sync.pendingWrites, 0);
  });
}
