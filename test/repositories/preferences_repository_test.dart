import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/preferences_config.dart';
import 'package:foodsavr/models/user_preferences_model.dart';
import 'package:foodsavr/repositories/preferences_repository.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
class _MockDocRef extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late _MockFirestore firestore;
  late _MockDocRef docRef;
  late SharedPreferencesWithCache prefs;
  late PreferencesRepository repository;

  Future<SharedPreferencesWithCache> createPrefs() {
    return SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(
        allowList: {PreferencesConfig.cacheKey},
      ),
    );
  }

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
  });

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = await createPrefs();
    firestore = _MockFirestore();
    docRef = _MockDocRef();
    when(
      () => firestore.doc('users/user-1/settings/preferences'),
    ).thenReturn(docRef);
    repository = PreferencesRepository(
      firestore,
      prefs,
      Logger(level: Level.off),
    );
  });

  _MockSnapshot snapshot(Map<String, dynamic>? data) {
    final snap = _MockSnapshot();
    when(() => snap.exists).thenReturn(data != null);
    when(() => snap.data()).thenReturn(data);
    return snap;
  }

  group('PreferencesRepository', () {
    test('getCached is null when nothing is cached', () {
      expect(repository.getCached('user-1'), isNull);
    });

    test('load returns remote preferences and refreshes the cache', () async {
      when(() => docRef.get()).thenAnswer(
        (_) async =>
            snapshot({'expiringSoonDays': 3, 'defaultInventoryId': 'inv-2'}),
      );

      final loaded = await repository.load('user-1');

      const expected = UserPreferences(
        expiringSoonDays: 3,
        defaultInventoryId: 'inv-2',
      );
      expect(loaded, expected);
      expect(repository.getCached('user-1'), expected);
    });

    test('load falls back to the cache when the backend is offline', () async {
      const cached = UserPreferences(expiringSoonDays: 2);
      when(() => docRef.set(any(), any())).thenAnswer((_) async {});
      await repository.save('user-1', cached);
      when(() => docRef.get()).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      // A fresh repository instance reads the persisted cache.
      final restarted = PreferencesRepository(
        firestore,
        await createPrefs(),
        Logger(level: Level.off),
      );
      expect(await restarted.load('user-1'), cached);
    });

    test(
      'load returns defaults when there is no document and no cache',
      () async {
        when(() => docRef.get()).thenAnswer((_) async => snapshot(null));

        expect(await repository.load('user-1'), const UserPreferences());
      },
    );

    test('load fills defaults for keys missing from the document', () async {
      when(
        () => docRef.get(),
      ).thenAnswer((_) async => snapshot({'defaultInventoryId': 'inv-1'}));

      final loaded = await repository.load('user-1');

      expect(loaded.expiringSoonDays, 6);
      expect(loaded.defaultInventoryId, 'inv-1');
    });

    test('save writes the cache and merges into the document', () async {
      const updated = UserPreferences(expiringSoonDays: 4);
      when(() => docRef.set(any(), any())).thenAnswer((_) async {});

      await repository.save('user-1', updated);

      expect(repository.getCached('user-1'), updated);
      final options =
          verify(
                () => docRef.set(updated.toJson(), captureAny()),
              ).captured.single
              as SetOptions;
      expect(options.merge, isTrue);
    });

    test('save keeps the cached value when the backend write fails', () async {
      const updated = UserPreferences(expiringSoonDays: 5);
      when(() => docRef.set(any(), any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      await expectLater(
        repository.save('user-1', updated),
        throwsA(isA<FirebaseException>()),
      );
      expect(repository.getCached('user-1'), updated);
    });

    test('the cache never leaks preferences to another account', () async {
      when(() => docRef.set(any(), any())).thenAnswer((_) async {});
      await repository.save(
        'user-1',
        const UserPreferences(defaultInventoryId: 'inv-9'),
      );

      expect(repository.getCached('user-2'), isNull);
    });
  });
}
