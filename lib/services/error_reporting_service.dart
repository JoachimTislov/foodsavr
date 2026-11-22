import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_error_reporter.dart';
import '../utils/config.dart';
import '../utils/monitoring_bridge.dart';

/// No-op error reporter used in emulator builds and when `ERROR_REPORTER=none`.
class NoopErrorReporter implements IErrorReporter {
  const NoopErrorReporter();

  @override
  String get name => 'none';

  @override
  bool get isEnabled => false;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> context = const {},
  }) async {}

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {}
}

/// Spark-tier error reporter writing bounded error records to `runtime_errors`.
class SparkFirestoreErrorReporter implements IErrorReporter {
  final FirebaseFirestore _firestore;
  final Logger _logger;
  final String _environment;

  SparkFirestoreErrorReporter({
    required FirebaseFirestore firestore,
    required Logger logger,
    required String environment,
  }) : _firestore = firestore,
       _logger = logger,
       _environment = environment;

  @override
  String get name => 'spark-firestore';

  @override
  bool get isEnabled => true;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> context = const {},
  }) async {
    try {
      await _firestore.collection('runtime_errors').add({
        'status': 'new',
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
        'environment': _environment,
        'deployment_level': 'firebase-spark',
        'error_type': error.runtimeType.toString(),
        'message': _truncate(error.toString(), 500),
        'reason': reason == null ? null : _truncate(reason, 200),
        'fatal': fatal,
        'stack_frames': _stackFrames(stack),
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
        'occurrence_count': 1,
      });
    } catch (e) {
      _logger.w('SparkFirestoreErrorReporter failed to persist error: $e');
    }
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) => recordError(
    details.exception,
    details.stack,
    reason: details.context?.toDescription(),
    fatal: fatal,
  );
}

/// Blaze `@firebase/crashlytics` JS-interop seam for web builds.
///
/// Android native `firebase_crashlytics` can attach to the same [IErrorReporter]
/// contract when the Android Crashlytics Gradle plugin and real `google-services.json`
/// are configured in CI.
class CrashlyticsWebErrorReporter implements IErrorReporter {
  final Logger _logger;
  final bool Function({
    required String errorType,
    required String message,
    required String stack,
    required bool fatal,
  })
  _jsRecorder;

  CrashlyticsWebErrorReporter({
    required Logger logger,
    bool Function({
          required String errorType,
          required String message,
          required String stack,
          required bool fatal,
        })
        jsRecorder =
        reportToCrashlyticsJs,
  }) : _logger = logger,
       _jsRecorder = jsRecorder;

  @override
  String get name => 'crashlytics-web';

  @override
  bool get isEnabled => true;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> context = const {},
  }) async {
    try {
      final handled = _jsRecorder(
        errorType: error.runtimeType.toString(),
        message: _truncate(error.toString(), 500),
        stack: _truncate(stack?.toString() ?? '', 2000),
        fatal: fatal,
      );
      if (!handled) {
        _logger.w(
          'Crashlytics JS collector unavailable; logged locally: $error',
        );
      }
    } catch (e) {
      _logger.w('CrashlyticsWebErrorReporter failed: $e');
    }
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) => recordError(
    details.exception,
    details.stack,
    reason: details.context?.toDescription(),
    fatal: fatal,
  );
}

/// HTTP collector adapter for external error-tracking services (GlitchTip,
/// PostHog, Grafana Faro, or custom intake relays).
class ExternalHttpErrorReporter implements IErrorReporter {
  final http.Client _client;
  final Uri _endpoint;
  final Logger _logger;
  final String _environment;

  ExternalHttpErrorReporter({
    required http.Client client,
    required Uri endpoint,
    required Logger logger,
    required String environment,
  }) : _client = client,
       _endpoint = endpoint,
       _logger = logger,
       _environment = environment;

  @override
  String get name => 'external';

  @override
  bool get isEnabled => true;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> context = const {},
  }) async {
    try {
      final payload = jsonEncode({
        'source': 'external',
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
        'environment': _environment,
        'error_type': error.runtimeType.toString(),
        'message': _truncate(error.toString(), 500),
        'reason': reason == null ? null : _truncate(reason, 200),
        'fatal': fatal,
        'stack_frames': _stackFrames(stack),
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _client
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      _logger.w('ExternalHttpErrorReporter failed to post error: $e');
    }
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) => recordError(
    details.exception,
    details.stack,
    reason: details.context?.toDescription(),
    fatal: fatal,
  );
}

/// DI-registered facade routing uncaught errors to the configured backend adapter.
@LazySingleton(as: IErrorReporter)
class ErrorReportingService implements IErrorReporter {
  final IErrorReporter _delegate;
  final Logger _logger;
  bool _recording = false;

  ErrorReportingService({
    required IErrorReporter delegate,
    required Logger logger,
  }) : _delegate = delegate,
       _logger = logger;

  @factoryMethod
  factory ErrorReportingService.fromConfig(
    Logger logger,
    http.Client httpClient,
    FirebaseFirestore firestore,
  ) => ErrorReportingService(
    delegate: buildReporterForMode(
      mode: Config.errorReporter,
      useEmulators: Config.useEmulators,
      environment: Config.environment,
      collectorEndpoint: Config.errorCollectorEndpoint,
      logger: logger,
      httpClient: httpClient,
      firestore: firestore,
    ),
    logger: logger,
  );

  static IErrorReporter buildReporterForMode({
    required String mode,
    required bool useEmulators,
    required String environment,
    required String collectorEndpoint,
    required Logger logger,
    required http.Client httpClient,
    required FirebaseFirestore firestore,
  }) {
    if (useEmulators) {
      return const NoopErrorReporter();
    }
    switch (mode.trim().toLowerCase()) {
      case 'spark-firestore':
        return SparkFirestoreErrorReporter(
          firestore: firestore,
          logger: logger,
          environment: environment,
        );
      case 'crashlytics-web':
        return CrashlyticsWebErrorReporter(logger: logger);
      case 'external':
        final uri = Uri.tryParse(collectorEndpoint.trim());
        if (uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty) {
          return ExternalHttpErrorReporter(
            client: httpClient,
            endpoint: uri,
            logger: logger,
            environment: environment,
          );
        }
        logger.w(
          'ERROR_REPORTER=external requires a valid ERROR_COLLECTOR_ENDPOINT; falling back to no-op.',
        );
        return const NoopErrorReporter();
      case 'none':
      case '':
      default:
        return const NoopErrorReporter();
    }
  }

  @override
  String get name => _delegate.name;

  @override
  bool get isEnabled => _delegate.isEnabled;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> context = const {},
  }) async {
    if (_recording) return;
    _recording = true;
    try {
      await _delegate.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
        context: context,
      );
    } catch (e) {
      _logger.w('ErrorReportingService suppressed error while recording: $e');
    } finally {
      _recording = false;
    }
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = false,
  }) async {
    if (_recording) return;
    _recording = true;
    try {
      await _delegate.recordFlutterError(details, fatal: fatal);
    } catch (e) {
      _logger.w(
        'ErrorReportingService suppressed error while recording FlutterError: $e',
      );
    } finally {
      _recording = false;
    }
  }
}

String _truncate(String value, int maxLen) {
  if (value.length <= maxLen) return value;
  return '${value.substring(0, maxLen - 3)}...';
}

List<String> _stackFrames(StackTrace? stack) {
  if (stack == null) return const [];
  return stack
      .toString()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .take(12)
      .map((line) => _truncate(line, 240))
      .toList();
}
