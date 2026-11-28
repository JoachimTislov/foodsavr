import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/user_preferences_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/in_memory_preferences_repository.dart';

class _MockAuthService extends Mock implements IAuthService {}

class _MockCollectionService extends Mock implements CollectionService {}

class _MockUser extends Mock implements User {}

/// Returns the backend value as of the start of the load, like a Firestore
/// read issued before a concurrent write.
class _SnapshotPreferencesRepository extends InMemoryPreferencesRepository {
  @override
  Future<UserPreferences> load(String userId) async {
    final snapshot = remote[userId];
    await loadGate?.future;
    return snapshot ?? const UserPreferences();
  }
}

class _FailingSaveRepository extends InMemoryPreferencesRepository {
  @override
  Future<void> save(String userId, UserPreferences preferences) async {
    cache[userId] = preferences;
    throw Exception('permission-denied');
  }
}

Collection _inventory(String id) =>
    Collection(id: id, name: id, productIds: const [], userId: 'user-1');

void main() {
  late _MockAuthService auth;
  late _MockCollectionService collections;
  late InMemoryPreferencesRepository repository;
  late StreamController<User?> authChanges;
  late PreferencesController controller;

  PreferencesController create() => PreferencesController(
    auth,
    repository,
    collections,
    Logger(level: Level.off),
  );

  setUp(() {
    auth = _MockAuthService();
    collections = _MockCollectionService();
    repository = InMemoryPreferencesRepository();
    authChanges = StreamController<User?>.broadcast();
    when(() => auth.authStateChanges).thenAnswer((_) => authChanges.stream);
    when(() => auth.getUserId()).thenReturn('user-1');
  });

  tearDown(() async {
    controller.dispose();
    await authChanges.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('PreferencesController', () {
    void stubInventories(List<Collection> inventories) => when(
      () => collections.getCollectionsForUser(
        'user-1',
        type: CollectionType.inventory,
      ),
    ).thenAnswer((_) async => inventories);

    test('resolves no default without inventories', () async {
      repository.remote['user-1'] = const UserPreferences(
        defaultInventoryId: 'deleted',
      );
      stubInventories(const []);
      controller = create();
      await settle();

      expect(await controller.resolveDefaultInventoryId(), isNull);
    });

    test('falls back when the default inventory was deleted', () async {
      repository.remote['user-1'] = const UserPreferences(
        defaultInventoryId: 'deleted',
      );
      stubInventories([_inventory('kept')]);
      controller = create();
      await settle();

      expect(await controller.resolveDefaultInventoryId(), 'kept');
    });

    test('forgets only the deleted default inventory', () async {
      repository.remote['user-1'] = const UserPreferences(
        defaultInventoryId: 'chosen',
      );
      controller = create();
      await settle();

      await controller.forgetDefaultInventory('other');
      expect(controller.defaultInventoryId, 'chosen');
      expect(repository.saved, isEmpty);

      await controller.forgetDefaultInventory('chosen');
      expect(controller.defaultInventoryId, isNull);
      expect(repository.remote['user-1']!.defaultInventoryId, isNull);
    });

    test('forgets the default locally when the sync fails', () async {
      repository = _FailingSaveRepository();
      repository.cache['user-1'] = const UserPreferences(
        defaultInventoryId: 'chosen',
      );
      controller = create();
      await settle();

      await controller.forgetDefaultInventory('chosen');

      expect(controller.defaultInventoryId, isNull);
    });

    test('starts from the cache and then applies the backend value', () async {
      repository.cache['user-1'] = const UserPreferences(expiringSoonDays: 2);
      repository.remote['user-1'] = const UserPreferences(expiringSoonDays: 9);
      controller = create();

      expect(controller.expiringSoonDays, 2);
      await settle();
      expect(controller.expiringSoonDays, 9);
    });

    test('exposes defaults when nothing is stored', () async {
      controller = create();
      await settle();

      expect(controller.expiringSoonDays, 6);
      expect(controller.defaultInventoryId, isNull);
    });

    test('setExpiringSoonDays updates, notifies, and saves', () async {
      controller = create();
      var notified = 0;
      controller.addListener(() => notified++);

      await controller.setExpiringSoonDays(3);

      expect(controller.expiringSoonDays, 3);
      expect(notified, 1);
      expect(repository.saved.single, (
        'user-1',
        const UserPreferences(expiringSoonDays: 3),
      ));
    });

    test('setExpiringSoonDays clamps to the supported range', () async {
      controller = create();

      await controller.setExpiringSoonDays(500);
      expect(controller.expiringSoonDays, 30);
      await controller.setExpiringSoonDays(-4);
      expect(controller.expiringSoonDays, 1);
    });

    test('setting an unchanged value neither notifies nor saves', () async {
      controller = create();
      await settle();
      var notified = false;
      controller.addListener(() => notified = true);

      await controller.setExpiringSoonDays(6);

      expect(notified, isFalse);
      expect(repository.saved, isEmpty);
    });

    test('setDefaultInventoryId can be cleared again', () async {
      controller = create();

      await controller.setDefaultInventoryId('inv-2');
      expect(controller.defaultInventoryId, 'inv-2');
      await controller.setDefaultInventoryId(null);
      expect(controller.defaultInventoryId, isNull);
    });

    test('signing out resets to defaults without saving', () async {
      repository.cache['user-1'] = const UserPreferences(expiringSoonDays: 2);
      controller = create();
      expect(controller.expiringSoonDays, 2);

      authChanges.add(null);
      await settle();

      expect(controller.expiringSoonDays, 6);
      await controller.setExpiringSoonDays(3);
      expect(repository.saved, isEmpty);
    });

    test('switching account loads that account\'s preferences', () async {
      repository.remote['user-2'] = const UserPreferences(expiringSoonDays: 4);
      controller = create();
      await settle();

      final user = _MockUser();
      when(() => user.uid).thenReturn('user-2');
      when(() => auth.getUserId()).thenReturn('user-2');
      authChanges.add(user);
      await settle();

      expect(controller.expiringSoonDays, 4);
    });

    test('a slow load from a previous account is discarded', () async {
      repository.remote['user-1'] = const UserPreferences(expiringSoonDays: 9);
      repository.loadGate = Completer<void>();
      controller = create();

      authChanges.add(null);
      await settle();
      repository.loadGate!.complete();
      await settle();

      expect(controller.expiringSoonDays, 6);
    });

    test(
      'a load started before a local change does not overwrite it',
      () async {
        repository = _SnapshotPreferencesRepository();
        repository.remote['user-1'] = const UserPreferences(
          expiringSoonDays: 9,
        );
        repository.loadGate = Completer<void>();
        controller = create();

        await controller.setExpiringSoonDays(3);
        repository.loadGate!.complete();
        await settle();

        expect(controller.expiringSoonDays, 3);
      },
    );

    test('a failed sync is reported and the change kept locally', () async {
      repository = _FailingSaveRepository();
      controller = create();
      await settle();

      await expectLater(controller.setExpiringSoonDays(3), throwsException);
      expect(controller.expiringSoonDays, 3);
      expect(repository.getCached('user-1')?.expiringSoonDays, 3);
    });

    group('resolveDefaultInventoryId', () {
      setUp(() {
        when(
          () => collections.getCollectionsForUser(
            'user-1',
            type: CollectionType.inventory,
          ),
        ).thenAnswer((_) async => [_inventory('a'), _inventory('b')]);
      });

      test('returns null when the inventories cannot be loaded', () async {
        when(
          () => collections.getCollectionsForUser(
            'user-1',
            type: CollectionType.inventory,
          ),
        ).thenThrow(Exception('offline'));
        controller = create();
        expect(await controller.resolveDefaultInventoryId(), isNull);
      });

      test('returns the first inventory without a preference', () async {
        controller = create();
        expect(await controller.resolveDefaultInventoryId(), 'a');
      });

      test('returns the chosen inventory', () async {
        controller = create();
        await controller.setDefaultInventoryId('b');
        expect(await controller.resolveDefaultInventoryId(), 'b');
        expect(
          await controller.resolveDefaultInventoryId(userId: 'user-1'),
          'b',
        );
      });

      test('returns null when signed out', () async {
        when(() => auth.getUserId()).thenReturn(null);
        controller = create();
        expect(await controller.resolveDefaultInventoryId(), isNull);
      });

      test('ignores the local choice for another user', () async {
        controller = create();
        await controller.setDefaultInventoryId('b');
        when(
          () => collections.getCollectionsForUser(
            'user-9',
            type: CollectionType.inventory,
          ),
        ).thenAnswer((_) async => [_inventory('x'), _inventory('b')]);

        expect(
          await controller.resolveDefaultInventoryId(userId: 'user-9'),
          'x',
        );
      });
    });
  });
}
