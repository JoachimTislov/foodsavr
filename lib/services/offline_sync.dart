import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import 'barcode_lookup_queue.dart';
import 'product_service.dart';

/// Replays barcode lookups queued while offline: at start, whenever the app
/// resumes, and periodically while the queue is not empty.
@lazySingleton
class OfflineSync {
  static const retryInterval = Duration(seconds: 30);

  final ProductService _productService;
  final BarcodeLookupQueue _queue;
  final Logger _logger;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  OfflineSync(this._productService, this._queue, this._logger);

  void start() {
    if (_timer != null) return;
    _lifecycle = AppLifecycleListener(onResume: replay);
    _timer = Timer.periodic(retryInterval, (_) => replay());
    replay();
  }

  /// Replays the queue unless it is empty; failures are logged and retried on
  /// the next trigger.
  void replay() {
    if (_queue.length == 0) return;
    unawaited(
      _productService.replayQueuedLookups().then<void>(
        (_) {},
        onError: (Object e) =>
            _logger.w('Queued barcode lookup replay failed: ${e.runtimeType}'),
      ),
    );
  }

  @disposeMethod
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
