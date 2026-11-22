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
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/in_memory_preferences_repository.dart';

class MockAuthService extends Mock implements IAuthService {}

class MockProductService extends Mock implements ProductService {}

class MockCollectionService extends Mock implements CollectionService {}

class MockUser extends Mock implements User {}

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
    );
  });

  tearDown(() async {
    controller.dispose();
    preferences.dispose();
    await authChanges.close();
  });

  group('DashboardController', () {
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
        () => mockCollectionService.getCollectionsForUser(
          userId,
          type: CollectionType.inventory,
        ),
      ).thenAnswer((_) async => []);

      var notified = false;
      controller.addListener(() => notified = true);
      await controller.load();
      expect(notified, true);
      verify(
        () => mockProductService.getExpiringSoon(userId, expiringSoonDays: 6),
      ).called(1);
      verify(
        () => mockCollectionService.getCollectionsForUser(
          userId,
          type: CollectionType.inventory,
        ),
      ).called(1);
    });

    test('load uses the current user on every refresh', () async {
      when(() => mockAuthService.getUserId()).thenReturn('user_1');
      when(
        () => mockProductService.getExpiringSoon('user_1', expiringSoonDays: 6),
      ).thenAnswer((_) async => []);
      when(
        () => mockCollectionService.getCollectionsForUser(
          'user_1',
          type: CollectionType.inventory,
        ),
      ).thenAnswer((_) async => []);
      await controller.load();

      when(() => mockAuthService.getUserId()).thenReturn('user_2');
      when(
        () => mockProductService.getExpiringSoon('user_2', expiringSoonDays: 6),
      ).thenAnswer((_) async => []);
      when(
        () => mockCollectionService.getCollectionsForUser(
          'user_2',
          type: CollectionType.inventory,
        ),
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
          () => mockCollectionService.getCollectionsForUser(
            'user_1',
            type: CollectionType.inventory,
          ),
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
        () => mockCollectionService.getCollectionsForUser(
          'user_1',
          type: CollectionType.inventory,
        ),
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
          () => mockCollectionService.getCollectionsForUser(
            'user_1',
            type: CollectionType.inventory,
          ),
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
  });
}
