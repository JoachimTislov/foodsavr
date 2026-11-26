import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:foodsavr/services/sync_status.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/repositories/collection_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockWriteBatch extends Mock implements WriteBatch {}

void main() {
  late _MockFirestore firestore;
  late _MockDocumentReference document;
  late _MockWriteBatch batch;
  late CollectionRepository repository;
  const populated = Collection(
    id: 'c1',
    name: 'Fridge',
    productIds: ['p1'],
    userId: 'u1',
  );

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    Future<StateError?> handler(Transaction _) async => null;
    registerFallbackValue(handler);
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(SetOptions(merge: true));
    registerFallbackValue(_MockDocumentReference());
  });

  void transactionFails(Object error) => when(
    () => firestore.runTransaction<StateError?>(
      any(),
      timeout: any(named: 'timeout'),
    ),
  ).thenAnswer((_) async => throw error);

  setUp(() {
    firestore = _MockFirestore();
    document = _MockDocumentReference();
    batch = _MockWriteBatch();
    final collections = _MockCollectionReference();
    when(() => firestore.collection('collections')).thenReturn(collections);
    when(() => collections.doc(any())).thenReturn(document);
    when(() => document.id).thenReturn('c1');
    when(() => firestore.batch()).thenReturn(batch);
    when(() => document.update(any())).thenAnswer((_) async {});
    when(() => document.set(any(), any())).thenAnswer((_) async {});
    when(() => batch.commit()).thenAnswer((_) async {});
    repository = CollectionRepository(
      firestore,
      SyncStatus(Logger(level: Level.off)),
    );
  });

  for (final (label, error) in [
    ('unavailable', FirebaseException(plugin: 'p', code: 'unavailable')),
    ('a timeout', TimeoutException('slow')),
    (
      'a native deadline',
      FirebaseException(plugin: 'p', code: 'deadline-exceeded'),
    ),
  ]) {
    test('$label queues adds, bulk adds and populated creates', () async {
      transactionFails(error);

      await repository.addProduct('c1', 'p1');
      await repository.addProducts('c1', ['p1', 'p2']);
      await repository.add(populated);
      await repository.addCollectionsInBatch([populated]);

      final updates = verify(() => document.update(captureAny())).captured;
      expect(updates, hasLength(2));
      for (final update in updates.cast<Map<Object, Object?>>()) {
        expect(update.keys, ['productIds']);
        expect(update['productIds'], isA<FieldValue>());
      }
      final created =
          verify(() => document.set(captureAny(), any())).captured.single
              as Map<String, dynamic>;
      expect(created['productIds'], isA<FieldValue>());
      verify(
        () => batch.set<Map<String, dynamic>>(document, any(), any()),
      ).called(1);
      verify(() => batch.commit()).called(1);
    });
  }

  test(
    'a transaction that misses the deadline before staging queues',
    () async {
      final pending = Completer<StateError?>();
      addTearDown(() => pending.complete(null));
      when(
        () => firestore.runTransaction<StateError?>(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) => pending.future);

      await repository
          .addProduct('c1', 'p1')
          .timeout(const Duration(seconds: 5));

      verify(() => document.update(any())).called(1);
    },
  );

  test('a queued add returns before the server acknowledges it', () async {
    transactionFails(FirebaseException(plugin: 'p', code: 'unavailable'));
    final acknowledgement = Completer<void>();
    addTearDown(acknowledgement.complete);
    when(
      () => document.update(any()),
    ).thenAnswer((_) => acknowledgement.future);

    await repository.addProduct('c1', 'p1').timeout(const Duration(seconds: 2));

    expect(acknowledgement.isCompleted, isFalse);
  });

  test('a queued add rejected before returning surfaces the error', () async {
    transactionFails(FirebaseException(plugin: 'p', code: 'unavailable'));
    when(() => document.update(any())).thenAnswer(
      (_) async =>
          throw FirebaseException(plugin: 'p', code: 'permission-denied'),
    );

    await expectLater(
      repository.addProduct('c1', 'p1'),
      throwsA(
        isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );
  });

  test('permission-denied never falls back', () async {
    transactionFails(FirebaseException(plugin: 'p', code: 'permission-denied'));

    for (final write in [
      () => repository.addProduct('c1', 'p1'),
      () => repository.add(populated),
      () => repository.addCollectionsInBatch([populated]),
    ]) {
      await expectLater(write(), throwsA(isA<FirebaseException>()));
    }
    verifyNever(() => document.update(any()));
    verifyNever(() => document.set(any(), any()));
    verifyNever(() => batch.commit());
  });

  test('a validation error never falls back', () async {
    when(
      () => firestore.runTransaction<StateError?>(
        any(),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) async => StateError('Product p1 is unavailable.'));

    await expectLater(repository.addProduct('c1', 'p1'), throwsStateError);
    await expectLater(repository.add(populated), throwsStateError);
    verifyNever(() => document.update(any()));
    verifyNever(() => document.set(any(), any()));
  });

  test('other transaction errors never fall back', () async {
    transactionFails(FirebaseException(plugin: 'p', code: 'aborted'));

    await expectLater(
      repository.addProduct('c1', 'p1'),
      throwsA(isA<FirebaseException>()),
    );
    verifyNever(() => document.update(any()));
  });
}
