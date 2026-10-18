import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/product_list_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/utils/view_mode_helper.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements IAuthService {}

class MockProductService extends Mock implements ProductService {}

class MockCollectionService extends Mock implements CollectionService {}

Product _product(String id, String name) =>
    Product(id: id, name: name, description: '', userId: 'user_1');

Collection _inventory(String id, String name, List<String> productIds) =>
    Collection(
      id: id,
      name: name,
      type: CollectionType.inventory,
      productIds: productIds,
      userId: 'user_1',
    );

void main() {
  late MockAuthService mockAuthService;
  late MockProductService mockProductService;
  late MockCollectionService mockCollectionService;

  ProductListController buildController({bool showGlobalProducts = false}) =>
      ProductListController(
        productService: mockProductService,
        collectionService: mockCollectionService,
        authService: mockAuthService,
        showGlobalProducts: showGlobalProducts,
      );

  setUp(() {
    mockAuthService = MockAuthService();
    mockProductService = MockProductService();
    mockCollectionService = MockCollectionService();
  });

  group('ProductListController', () {
    test('initial state is empty with normal view mode', () {
      final controller = buildController();
      expect(controller.products, isEmpty);
      expect(controller.productInventories, isEmpty);
      expect(controller.viewMode, ProductViewMode.normal);
      controller.dispose();
    });

    test('load clears state and notifies when user is null', () async {
      when(() => mockAuthService.getUserId()).thenReturn(null);
      final controller = buildController();
      var notified = false;
      controller.addListener(() => notified = true);
      await controller.load();
      expect(notified, true);
      expect(controller.products, isEmpty);
      expect(controller.productInventories, isEmpty);
      verifyNever(() => mockProductService.getProducts(any()));
      controller.dispose();
    });

    test(
      'load publishes products and inventory map in one notification',
      () async {
        const userId = 'user_1';
        final products = [_product('p1', 'Milk'), _product('p2', 'Bread')];
        final collections = [
          _inventory('c1', 'Fridge', ['p1']),
          _inventory('c2', 'Pantry', ['p1', 'p2']),
          Collection(
            id: 'c3',
            name: 'Shopping',
            type: CollectionType.shoppingList,
            productIds: ['p1'],
            userId: 'user_1',
          ),
        ];
        when(() => mockAuthService.getUserId()).thenReturn(userId);
        when(() => mockProductService.getProducts(userId, forceRefresh: false))
            .thenAnswer((_) async => products);
        when(() => mockCollectionService.getCollectionsForUser(userId))
            .thenAnswer((_) async => collections);

        final controller = buildController();
        var notifications = 0;
        controller.addListener(() => notifications++);
        await controller.load();

        expect(notifications, 1);
        expect(controller.products, same(products));
        expect(controller.productInventories['p1'], ['Fridge', 'Pantry']);
        expect(controller.productInventories['p2'], ['Pantry']);
        expect(controller.inventoryLoadError, isNull);
        controller.dispose();
      },
    );

    test('load uses the current user on every refresh', () async {
      const firstUserId = 'user_1';
      const secondUserId = 'user_2';
      when(() => mockAuthService.getUserId()).thenReturn(firstUserId);
      when(
        () => mockProductService.getProducts(firstUserId, forceRefresh: true),
      ).thenAnswer((_) async => []);
      when(() => mockCollectionService.getCollectionsForUser(firstUserId))
          .thenAnswer((_) async => []);

      final controller = buildController();
      await controller.load(forceRefresh: true);

      when(() => mockAuthService.getUserId()).thenReturn(secondUserId);
      when(
        () => mockProductService.getProducts(secondUserId, forceRefresh: true),
      ).thenAnswer((_) async => [_product('p9', 'Cheese')]);
      when(() => mockCollectionService.getCollectionsForUser(secondUserId))
          .thenAnswer((_) async => []);

      await controller.load(forceRefresh: true);

      expect(controller.products.map((p) => p.id), ['p9']);
      verify(
        () => mockProductService.getProducts(firstUserId, forceRefresh: true),
      ).called(1);
      verify(
        () => mockProductService.getProducts(secondUserId, forceRefresh: true),
      ).called(1);
      controller.dispose();
    });

    test('load fetches global products without collections', () async {
      when(() => mockProductService.getAllProducts())
          .thenAnswer((_) async => [_product('g1', 'Global')]);

      final controller = buildController(showGlobalProducts: true);
      await controller.load();

      expect(controller.products.map((p) => p.id), ['g1']);
      expect(controller.productInventories, isEmpty);
      verifyNever(() => mockCollectionService.getCollectionsForUser(any()));
      verifyNever(() => mockAuthService.getUserId());
      controller.dispose();
    });

    test(
      'load still publishes products when the inventory fetch fails',
      () async {
        const userId = 'user_1';
        final products = [_product('p1', 'Milk')];
        when(() => mockAuthService.getUserId()).thenReturn(userId);
        when(() => mockProductService.getProducts(userId, forceRefresh: false))
            .thenAnswer((_) async => products);
        when(() => mockCollectionService.getCollectionsForUser(userId))
            .thenAnswer((_) async => throw Exception('network down'));

        final controller = buildController();
        await controller.load();

        expect(controller.products, same(products));
        expect(controller.productInventories, isEmpty);
        expect(controller.inventoryLoadError, isNotNull);
        controller.dispose();
      },
    );

    test('setViewMode notifies only when the mode changes', () {
      final controller = buildController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setViewMode(ProductViewMode.details);
      expect(notifications, 1);
      expect(controller.viewMode, ProductViewMode.details);

      controller.setViewMode(ProductViewMode.details);
      expect(notifications, 1);
      controller.dispose();
    });
  });
}
