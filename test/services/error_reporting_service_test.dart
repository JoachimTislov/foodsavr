import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_error_reporter.dart';
import 'package:foodsavr/services/error_reporting_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockErrorReporter extends Mock implements IErrorReporter {}

void main() {
  late Logger logger;
  late _MockFirebaseFirestore mockFirestore;
  late _MockCollectionReference mockCollection;
  late _MockDocumentReference mockDocument;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(
      FlutterErrorDetails(exception: StateError('fallback')),
    );
  });

  setUp(() {
    logger = Logger(level: Level.off);
    mockFirestore = _MockFirebaseFirestore();
    mockCollection = _MockCollectionReference();
    mockDocument = _MockDocumentReference();
    when(
      () => mockFirestore.collection('runtime_errors'),
    ).thenReturn(mockCollection);
    when(() => mockCollection.add(any())).thenAnswer((_) async => mockDocument);
  });

  group('NoopErrorReporter', () {
    test('reports disabled metadata and ignores errors cleanly', () async {
      const reporter = NoopErrorReporter();
      expect(reporter.name, 'none');
      expect(reporter.isEnabled, isFalse);

      await reporter.recordError(StateError('ignored'), StackTrace.current);
      await reporter.recordFlutterError(
        FlutterErrorDetails(exception: StateError('ignored')),
      );
    });
  });

  group('ErrorReportingService.buildReporterForMode', () {
    test('always returns NoopErrorReporter when useEmulators is true', () {
      final client = MockClient((_) async => http.Response('{}', 200));
      for (final mode in [
        'spark-firestore',
        'crashlytics-web',
        'external',
        'none',
      ]) {
        final reporter = ErrorReportingService.buildReporterForMode(
          mode: mode,
          useEmulators: true,
          environment: 'development',
          collectorEndpoint: 'https://collector.example.com/events',
          logger: logger,
          httpClient: client,
          firestore: mockFirestore,
        );
        expect(reporter, isA<NoopErrorReporter>());
        expect(reporter.isEnabled, isFalse);
      }
    });

    test('selects SparkFirestoreErrorReporter for spark-firestore', () {
      final client = MockClient((_) async => http.Response('{}', 200));
      final reporter = ErrorReportingService.buildReporterForMode(
        mode: ' SPARK-FIRESTORE ',
        useEmulators: false,
        environment: 'production',
        collectorEndpoint: '',
        logger: logger,
        httpClient: client,
        firestore: mockFirestore,
      );
      expect(reporter, isA<SparkFirestoreErrorReporter>());
      expect(reporter.name, 'spark-firestore');
      expect(reporter.isEnabled, isTrue);
    });

    test('selects CrashlyticsWebErrorReporter for crashlytics-web', () {
      final client = MockClient((_) async => http.Response('{}', 200));
      final reporter = ErrorReportingService.buildReporterForMode(
        mode: 'crashlytics-web',
        useEmulators: false,
        environment: 'production',
        collectorEndpoint: '',
        logger: logger,
        httpClient: client,
        firestore: mockFirestore,
      );
      expect(reporter, isA<CrashlyticsWebErrorReporter>());
      expect(reporter.name, 'crashlytics-web');
      expect(reporter.isEnabled, isTrue);
    });

    test('selects ExternalHttpErrorReporter when endpoint is valid HTTP/S', () {
      final client = MockClient((_) async => http.Response('{}', 202));
      final reporter = ErrorReportingService.buildReporterForMode(
        mode: 'external',
        useEmulators: false,
        environment: 'production',
        collectorEndpoint: 'https://collector.example.com/ingest',
        logger: logger,
        httpClient: client,
        firestore: mockFirestore,
      );
      expect(reporter, isA<ExternalHttpErrorReporter>());
      expect(reporter.name, 'external');
      expect(reporter.isEnabled, isTrue);
    });

    test(
      'falls back to NoopErrorReporter when external endpoint is invalid',
      () {
        final client = MockClient((_) async => http.Response('{}', 200));
        for (final endpoint in [
          '',
          'not-a-url',
          'javascript:alert(1)',
          'ftp://x',
        ]) {
          final reporter = ErrorReportingService.buildReporterForMode(
            mode: 'external',
            useEmulators: false,
            environment: 'production',
            collectorEndpoint: endpoint,
            logger: logger,
            httpClient: client,
            firestore: mockFirestore,
          );
          expect(reporter, isA<NoopErrorReporter>());
        }
      },
    );

    test('returns NoopErrorReporter for none or unknown mode', () {
      final client = MockClient((_) async => http.Response('{}', 200));
      for (final mode in ['', 'none', 'unknown-adapter']) {
        final reporter = ErrorReportingService.buildReporterForMode(
          mode: mode,
          useEmulators: false,
          environment: 'production',
          collectorEndpoint: '',
          logger: logger,
          httpClient: client,
          firestore: mockFirestore,
        );
        expect(reporter, isA<NoopErrorReporter>());
      }
    });
  });

  group('SparkFirestoreErrorReporter', () {
    test('writes bounded document to runtime_errors collection', () async {
      final reporter = SparkFirestoreErrorReporter(
        firestore: mockFirestore,
        logger: logger,
        environment: 'production',
      );

      final longMessage = 'X' * 700;
      final longReason = 'R' * 300;
      final stack = StackTrace.fromString(
        List.generate(20, (i) => '#$i frame_${'A' * 300}').join('\n'),
      );

      await reporter.recordError(
        Exception(longMessage),
        stack,
        reason: longReason,
        fatal: true,
      );

      final captured = verify(() => mockCollection.add(captureAny())).captured;
      expect(captured, hasLength(1));
      final doc = captured.single as Map<String, dynamic>;
      expect(doc['status'], 'new');
      expect(doc['environment'], 'production');
      expect(doc['deployment_level'], 'firebase-spark');
      expect(doc['fatal'], isTrue);
      expect(doc['occurrence_count'], 1);
      expect((doc['message'] as String).length, lessThanOrEqualTo(500));
      expect((doc['reason'] as String).length, lessThanOrEqualTo(200));
      final frames = doc['stack_frames'] as List<String>;
      expect(frames, hasLength(12));
      for (final frame in frames) {
        expect(frame.length, lessThanOrEqualTo(240));
      }
      expect(DateTime.tryParse(doc['occurred_at'] as String), isNotNull);
    });

    test('suppresses Firestore failures without rethrowing', () async {
      when(() => mockCollection.add(any())).thenThrow(Exception('offline'));
      final reporter = SparkFirestoreErrorReporter(
        firestore: mockFirestore,
        logger: logger,
        environment: 'production',
      );

      await reporter.recordFlutterError(
        FlutterErrorDetails(
          exception: StateError('widget error'),
          stack: StackTrace.current,
          context: ErrorDescription('while building'),
        ),
        fatal: false,
      );
      verify(() => mockCollection.add(any())).called(1);
    });
  });

  group('CrashlyticsWebErrorReporter', () {
    test('forwards bounded payload to JS recorder callback', () async {
      String? capturedType;
      String? capturedMessage;
      String? capturedStack;
      bool? capturedFatal;

      final reporter = CrashlyticsWebErrorReporter(
        logger: logger,
        jsRecorder:
            ({
              required String errorType,
              required String message,
              required String stack,
              required bool fatal,
            }) {
              capturedType = errorType;
              capturedMessage = message;
              capturedStack = stack;
              capturedFatal = fatal;
              return true;
            },
      );

      await reporter.recordFlutterError(
        FlutterErrorDetails(
          exception: StateError('M' * 650),
          stack: StackTrace.fromString('S' * 2500),
        ),
        fatal: true,
      );

      expect(capturedType, 'StateError');
      expect(capturedMessage!.length, lessThanOrEqualTo(500));
      expect(capturedStack!.length, lessThanOrEqualTo(2000));
      expect(capturedFatal, isTrue);
    });

    test('handles unavailable or throwing JS bridge safely', () async {
      final unavailable = CrashlyticsWebErrorReporter(
        logger: logger,
        jsRecorder:
            ({
              required String errorType,
              required String message,
              required String stack,
              required bool fatal,
            }) => false,
      );
      await unavailable.recordError(StateError('boom'), StackTrace.current);

      final throwing = CrashlyticsWebErrorReporter(
        logger: logger,
        jsRecorder:
            ({
              required String errorType,
              required String message,
              required String stack,
              required bool fatal,
            }) => throw StateError('js failure'),
      );
      await throwing.recordError(StateError('boom'), StackTrace.current);
    });
  });

  group('ExternalHttpErrorReporter', () {
    test('posts normalized JSON payload to configured endpoint', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{"ok":true}', 202);
      });

      final reporter = ExternalHttpErrorReporter(
        client: client,
        endpoint: Uri.parse('https://collector.example.com/ingest'),
        logger: logger,
        environment: 'production',
      );

      await reporter.recordFlutterError(
        FlutterErrorDetails(
          exception: FormatException('bad payload'),
          stack: StackTrace.current,
          context: ErrorDescription('during parse'),
        ),
        fatal: true,
      );

      expect(capturedRequest.method, 'POST');
      expect(
        capturedRequest.url.toString(),
        'https://collector.example.com/ingest',
      );
      expect(
        capturedRequest.headers['Content-Type'],
        contains('application/json'),
      );
      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['source'], 'external');
      expect(body['environment'], 'production');
      expect(body['error_type'], 'FormatException');
      expect(body['reason'], 'during parse');
      expect(body['fatal'], isTrue);
      expect(body['stack_frames'], isA<List<dynamic>>());
    });

    test('suppresses HTTP transport failures', () async {
      final client = MockClient((_) async => throw Exception('timeout'));
      final reporter = ExternalHttpErrorReporter(
        client: client,
        endpoint: Uri.parse('https://collector.example.com/ingest'),
        logger: logger,
        environment: 'production',
      );

      await reporter.recordError(StateError('network'), StackTrace.current);
    });
  });

  group('ErrorReportingService facade', () {
    test('prevents re-entrant recursive error reporting loops', () async {
      late ErrorReportingService service;
      var callCount = 0;
      final mockDelegate = _MockErrorReporter();
      when(() => mockDelegate.name).thenReturn('mock');
      when(() => mockDelegate.isEnabled).thenReturn(true);
      when(
        () => mockDelegate.recordError(
          any(),
          any(),
          reason: any(named: 'reason'),
          fatal: any(named: 'fatal'),
          context: any(named: 'context'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        // Attempt a nested recursive report while already recording.
        await service.recordError(StateError('nested'), null);
        await service.recordFlutterError(
          FlutterErrorDetails(exception: StateError('nested flutter')),
        );
      });

      service = ErrorReportingService(delegate: mockDelegate, logger: logger);
      expect(service.name, 'mock');
      expect(service.isEnabled, isTrue);

      await service.recordError(StateError('outer'), StackTrace.current);
      expect(callCount, 1);

      // Re-entrancy flag resets after completion.
      await service.recordError(StateError('second'), StackTrace.current);
      expect(callCount, 2);
    });

    test('suppresses exceptions thrown by delegate and resets guard', () async {
      final mockDelegate = _MockErrorReporter();
      when(() => mockDelegate.name).thenReturn('mock');
      when(() => mockDelegate.isEnabled).thenReturn(true);
      when(
        () => mockDelegate.recordError(
          any(),
          any(),
          reason: any(named: 'reason'),
          fatal: any(named: 'fatal'),
          context: any(named: 'context'),
        ),
      ).thenThrow(StateError('delegate failed'));
      when(
        () =>
            mockDelegate.recordFlutterError(any(), fatal: any(named: 'fatal')),
      ).thenAnswer((_) async {});

      final service = ErrorReportingService(
        delegate: mockDelegate,
        logger: logger,
      );

      await service.recordError(StateError('outer'), null);
      await service.recordFlutterError(
        FlutterErrorDetails(exception: StateError('after failure')),
      );

      verify(
        () => mockDelegate.recordFlutterError(any(), fatal: false),
      ).called(1);
    });
  });
}
