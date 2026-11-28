import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodsavr/controllers/dashboard_controller.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/models/user_preferences_model.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/in_memory_preferences_repository.dart';

class MockAuthService extends Mock implements IAuthService {}

class MockProductService extends Mock implements ProductService {}

class MockCollectionService extends Mock implements CollectionService {}

class MockUser extends Mock implements User {}

Product _productExpiringIn(String id, int days) {
  final now = DateTime.now();
  return Product(
    id: id,
    name: 'Product $id',
    description: '',
    userId: 'user_1',
    expiries: [
      ExpiryEntry(
        quantity: 1,
        expirationDate: DateTime(now.year, now.month, now.day + days),
      ),
    ],
  );
}

void main() {
  late MockAuthService mockAuthService;
  late MockProductService mockProductService;
  late MockCollectionService mockCollectionService;
  late StreamController<User?> authChanges;
  late PreferencesController preferences;
  late DashboardController controller;

  setUp(() {
    mockAuthService = MockAuthService();
    mockProductService = MockProductService();
    mockCollectionService = MockCollectionService();
    authChanges = StreamController<User?>.broadcast();
    when(
      () => mockProductService.getExpired(any()),
    ).thenAnswer((_) async => []);
    when(
      () => mockProductService.getProducts(any()),
    ).thenAnswer((_) async => []);
    when(
      () => mockAuthService.authStateChanges,
    ).thenAnswer((_) => authChanges.stream);
    preferences = PreferencesController(
      mockAuthService,
      InMemoryPreferencesRepository(),
      mockCollectionService,
      Logger(level: Level.off),
    );
    controller = DashboardController(
      mockAuthService,
      mockProductService,
      mockCollectionService,
      preferences,
      Logger(level: Level.off),
    );
  });

  tearDown(() async {
    controller.dispose();
    preferences.dispose();
    await authChanges.close();
  });

  group('DashboardController', () {
    test(
      'keeps products with both expired and upcoming entries in both lists',
      () async {
        final mixed = _productExpiringIn('mixed', -1).copyWith(
          expiries: [
            ..._productExpiringIn('past', -1).expiries,
            ..._productExpiringIn('tomorrow', 1).expiries,
          ],
        );
        when(() => mockAuthService.getUserId()).thenReturn('user_1');
        when(
          () => mockProductService.getExpired('user_1'),
        ).thenAnswer((_) async => [_productExpiringIn('ten', -10), mixed]);
        when(
          () => mockProductService.getExpiringSoon(
            'user_1',
            expiringSoonDays: any(named: 'expiringSoonDays'),
          ),
        ).thenAnswer((_) async => [mixed, _productExpiringIn('three', 3)]);
        when(
          () => mockCollectionService.getCollectionsForUser('user_1'),
        ).thenAnswer((_) async => []);

        await controller.load();

        expect(controller.expired.map((p) => p.id), ['ten', 'mixed']);
        expect(controller.expiringSoon.map((p) => p.id), ['mixed', 'three']);
      },
    );

    test('initial state is empty', () {
      expect(controller.expiringSoon, isEmpty);
      expect(controller.inventories, isEmpty);
    });

    test('load clears state and notifies when user is null', () async {
      when(() => mockAuthService.getUserId()).thenReturn(null);
      var notified = false;
      controller.addListener(() => notified = true);
      await controller.load();
      expect(notified, true);
      expect(controller.expiringSoon, isEmpty);
      expect(controller.inventories, isEmpty);
      verifyNever(
        () => mockProductService.getExpiringSoon(
          any(),
          expiringSoonDays: any(named: 'expiringSoonDays'),
        ),
      );
    });

    test('load fetches with current user and notifies', () async {
      const userId = 'user_1';
      when(() => mockAuthService.getUserId()).thenReturn(userId);
      when(
        () => mockProductService.getExpiringSoon(userId, expiringSoonDays: 6),
      ).thenAnswer((_) async => []);
      when(
        () => mockCollectionService.getCollectionsForUser(userId),
      ).thenAnswer((_) async => []);

      var notified = false;
      controller.addListener(() => notified = true);
      await controller.load();
      expect(notified, true);
      verify(
        () => mockProductService.getExpiringSoon(userId, expiringSoonDays: 6),
      ).called(1);
      verify(
        () => mockCollectionService.getCollectionsForUser(userId),
      ).called(1);
    });

    test('load uses the current user on every refresh', () async {
      when(() => mockAuthService.getUserId()).thenReturn('user_1');
      when(
        () => mockProductService.getExpiringSoon('user_1', expiringSoonDays: 6),
      ).thenAnswer((_) async => []);
      when(
        () => mockCollectionService.getCollectionsForUser('user_1'),
      ).thenAnswer((_) async => []);
      await controller.load();

      when(() => mockAuthService.getUserId()).thenReturn('user_2');
      when(
        () => mockProductService.getExpiringSoon('user_2', expiringSoonDays: 6),
      ).thenAnswer((_) async => []);
      when(
        () => mockCollectionService.getCollectionsForUser('user_2'),
      ).thenAnswer((_) async => []);
      await controller.load();

      verify(
        () => mockProductService.getExpiringSoon('user_1', expiringSoonDays: 6),
      ).called(1);
      verify(
        () => mockProductService.getExpiringSoon('user_2', expiringSoonDays: 6),
      ).called(1);
    });

    test(
      'load discards results when a newer load or sign-out intervened',
      () async {
        final firstLoadProducts = Completer<List<Product>>();
        final firstLoadCollections = Completer<List<Collection>>();
        when(() => mockAuthService.getUserId()).thenReturn('user_1');
        when(
          () =>
              mockProductService.getExpiringSoon('user_1', expiringSoonDays: 6),
        ).thenAnswer((_) => firstLoadProducts.future);
        when(
          () => mockCollectionService.getCollectionsForUser('user_1'),
        ).thenAnswer((_) => firstLoadCollections.future);
        final firstLoad = controller.load();

        when(() => mockAuthService.getUserId()).thenReturn(null);
        await controller.load();
        expect(controller.expiringSoon, isEmpty);
        expect(controller.inventories, isEmpty);

        firstLoadProducts.complete(const []);
        firstLoadCollections.complete(const []);
        await firstLoad;

        expect(controller.expiringSoon, isEmpty);
        expect(controller.inventories, isEmpty);
      },
    );

    test('load uses the expiring-soon window from the preferences', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('user_1');
      when(() => mockAuthService.getUserId()).thenReturn('user_1');
      authChanges.add(user);
      await Future<void>.delayed(Duration.zero);
      await preferences.setExpiringSoonDays(10);
      when(
        () =>
            mockProductService.getExpiringSoon('user_1', expiringSoonDays: 10),
      ).thenAnswer((_) async => []);
      when(
        () => mockCollectionService.getCollectionsForUser('user_1'),
      ).thenAnswer((_) async => []);

      await controller.load();

      verify(
        () =>
            mockProductService.getExpiringSoon('user_1', expiringSoonDays: 10),
      ).called(1);
    });

    test(
      'reloads when the expiring-soon window changes after a load',
      () async {
        final user = MockUser();
        when(() => user.uid).thenReturn('user_1');
        when(() => mockAuthService.getUserId()).thenReturn('user_1');
        authChanges.add(user);
        await Future<void>.delayed(Duration.zero);
        when(
          () => mockProductService.getExpiringSoon(
            'user_1',
            expiringSoonDays: any(named: 'expiringSoonDays'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockCollectionService.getCollectionsForUser('user_1'),
        ).thenAnswer((_) async => []);
        await controller.load();

        await preferences.setExpiringSoonDays(3);
        await Future<void>.delayed(Duration.zero);

        verify(
          () =>
              mockProductService.getExpiringSoon('user_1', expiringSoonDays: 3),
        ).called(1);
      },
    );

    test('refresh reloads the preferences before the dashboard', () async {
      final user = MockUser();
      when(() => user.uid).thenReturn('user_1');
      when(() => mockAuthService.getUserId()).thenReturn('user_1');
      final repository = InMemoryPreferencesRepository();
      preferences = PreferencesController(
        mockAuthService,
        repository,
        mockCollectionService,
        Logger(level: Level.off),
      );
      controller = DashboardController(
        mockAuthService,
        mockProductService,
        mockCollectionService,
        preferences,
        Logger(level: Level.off),
      );
      await Future<void>.delayed(Duration.zero);
      // Another device changed the window in the backend.
      repository.remote['user_1'] = const UserPreferences(expiringSoonDays: 12);
      when(
        () => mockProductService.getExpiringSoon(
          'user_1',
          expiringSoonDays: any(named: 'expiringSoonDays'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockCollectionService.getCollectionsForUser('user_1'),
      ).thenAnswer((_) async => []);

      await controller.refresh();

      verify(
        () =>
            mockProductService.getExpiringSoon('user_1', expiringSoonDays: 12),
      ).called(1);
    });

    test(
      'does not load on a preference change before the first load',
      () async {
        final user = MockUser();
        when(() => user.uid).thenReturn('user_1');
        when(() => mockAuthService.getUserId()).thenReturn('user_1');
        authChanges.add(user);
        await Future<void>.delayed(Duration.zero);

        await preferences.setExpiringSoonDays(3);

        verifyNever(
          () => mockProductService.getExpiringSoon(
            any(),
            expiringSoonDays: any(named: 'expiringSoonDays'),
          ),
        );
      },
    );

    group('empty account', () {
      setUp(() {
        when(() => mockAuthService.getUserId()).thenReturn('user_1');
        when(
          () => mockProductService.getExpiringSoon(
            'user_1',
            expiringSoonDays: any(named: 'expiringSoonDays'),
          ),
        ).thenAnswer((_) async => []);
      });

      void stubCollections(List<Collection> collections) => when(
        () => mockCollectionService.getCollectionsForUser('user_1'),
      ).thenAnswer((_) async => collections);

      Collection collection(CollectionType type) => Collection(
        id: type.name,
        name: type.name,
        productIds: const [],
        userId: 'user_1',
        type: type,
      );

      test('is empty without collections and products', () async {
        stubCollections(const []);

        await controller.load();

        expect(controller.isEmptyAccount, isTrue);
        expect(controller.inventories, isEmpty);
      });

      test('is not empty with only a shopping list', () async {
        stubCollections([collection(CollectionType.shoppingList)]);

        await controller.load();

        expect(controller.isEmptyAccount, isFalse);
        expect(controller.inventories, isEmpty);
        verifyNever(() => mockProductService.getProducts(any()));
      });

      test('is not empty with only a product', () async {
        stubCollections(const []);
        when(
          () => mockProductService.getProducts('user_1'),
        ).thenAnswer((_) async => [_productExpiringIn('milk', 30)]);

        await controller.load();

        expect(controller.isEmptyAccount, isFalse);
      });

      test('splits inventories from shopping lists with counts', () async {
        final collections = [
          collection(CollectionType.inventory),
          collection(CollectionType.shoppingList),
        ];
        stubCollections(collections);
        when(
          () => mockCollectionService.resolveCounts('user_1', collections),
        ).thenAnswer((_) async => {'inventory': 2, 'shoppingList': 5});

        await controller.load();

        expect(controller.inventories.map((c) => c.id), ['inventory']);
        expect(controller.shoppingLists.map((c) => c.id), ['shoppingList']);
        expect(controller.productCounts, {'inventory': 2, 'shoppingList': 5});

        when(() => mockAuthService.getUserId()).thenReturn(null);
        await controller.load();
        expect(controller.shoppingLists, isEmpty);
        expect(controller.productCounts, isEmpty);
      });

      test('loads without counts when they cannot be resolved', () async {
        final collections = [collection(CollectionType.shoppingList)];
        stubCollections(collections);
        when(
          () => mockCollectionService.resolveCounts('user_1', collections),
        ).thenThrow(StateError('offline'));

        await controller.load();

        expect(controller.shoppingLists, hasLength(1));
        expect(controller.productCounts, isEmpty);
      });

      test('follows the last inventory being deleted and sign-out', () async {
        stubCollections([collection(CollectionType.inventory)]);
        await controller.load();
        expect(controller.inventories, hasLength(1));
        expect(controller.isEmptyAccount, isFalse);

        stubCollections(const []);
        await controller.load();
        expect(controller.inventories, isEmpty);
        expect(controller.isEmptyAccount, isTrue);

        when(() => mockAuthService.getUserId()).thenReturn(null);
        await controller.load();
        expect(controller.isEmptyAccount, isFalse);
      });
    });
  });
}
