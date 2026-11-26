import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

/// Counts local writes that the backend has not acknowledged yet.
///
/// Firestore applies a write to its local cache at once and completes the
/// write's Future only on server acknowledgement, which never happens while
/// offline. [queue] lets callers continue after a short wait and keeps the
/// write counted until it is acknowledged.
@lazySingleton
class SyncStatus extends ChangeNotifier {
  static const acknowledgementTimeout = Duration(milliseconds: 500);

  final Logger _logger;
  final Duration _timeout;
  int _pendingWrites = 0;

  SyncStatus(this._logger) : _timeout = acknowledgementTimeout;

  @visibleForTesting
  SyncStatus.withTimeout(this._logger, this._timeout);

  /// Writes applied locally and waiting for the server.
  int get pendingWrites => _pendingWrites;

  /// Starts [write] and returns once it is acknowledged, or after the
  /// acknowledgement timeout while it stays queued. An error raised before the
  /// timeout is rethrown; a later rejection is logged, and Firestore rolls the
  /// write back in its local cache.
  Future<void> queue(Future<void> Function() write) async {
    final acknowledged = Future.sync(write);
    _pendingWrites++;
    notifyListeners();
    unawaited(
      acknowledged
          .then<void>(
            (_) {},
            onError: (Object error) =>
                _logger.w('Queued write failed: ${error.runtimeType}'),
          )
          .whenComplete(() {
            _pendingWrites--;
            notifyListeners();
          }),
    );
    try {
      await acknowledged.timeout(_timeout);
    } on TimeoutException {
      // Offline: Firestore syncs the queued write after reconnecting.
    }
  }
}
