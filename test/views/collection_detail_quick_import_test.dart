import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:foodsavr/views/collection_detail_view.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_translation_loader.dart';
import '../support/fake_product_repository.dart';

class _MockAuthService extends Mock implements IAuthService {}

class _MockCollectionService extends Mock implements CollectionService {}

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

class _FakeCollection extends Fake implements Collection {}

class _FakePreferences extends ChangeNotifier implements PreferencesController {
  @override
  int get expiringSoonDays => 6;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late TestTranslationLoader translations;
  late FakeProductRepository repository;
  late _MockCollectionService collectionService;
  late _FakePreferences preferences;

  const userId = 'user-1';
  const shoppingList = Collection(
    id: 'shop-1',
    name: 'Weekly Groceries',
    userId: userId,
    type: CollectionType.shoppingList,
    productIds: [],
  );
  const inventory = Collection(
    id: 'inv-1',
    name: 'Fridge',
    userId: userId,
    type: CollectionType.inventory,
    productIds: [],
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(_FakeCollection());
    translations = TestTranslationLoader();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    EasyLocalization.logger.enableBuildModes = [];
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(
      const Product(id: 'x', name: 'x', description: '', userId: 'u'),
    );
  });

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    repository = FakeProductRepository();
    final shelfLife = _MockShelfLifeService();
    when(() => shelfLife.estimateExpiration(any())).thenReturn(null);
    final productService = ProductService(
      repository,
      ProductModelValidator(),
      shelfLife,
      Logger(level: Level.off),
    );
    final auth = _MockAuthService();
    when(auth.getUserId).thenReturn(userId);
    collectionService = _MockCollectionService();
    preferences = _FakePreferences();

    getIt
      ..registerSingleton<ProductService>(productService)
      ..registerSingleton<CollectionService>(collectionService)
      ..registerSingleton<IAuthService>(auth)
      ..registerSingleton<PreferencesController>(preferences);
  });

  tearDown(() {
    preferences.dispose();
    return getIt.reset();
  });

  Future<void> pumpDetail(WidgetTester tester, Collection collection) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: translations,
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: CollectionDetailView(collection: collection),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shopping list empty state shows Quick import and imports items',
    (tester) async {
      final addedIds = <String>[];
      when(() => collectionService.getCollection('shop-1')).thenAnswer(
        (_) async => shoppingList.copyWith(productIds: List.of(addedIds)),
      );
      when(() => collectionService.loadContents(any())).thenAnswer((_) async {
        final items = repository.products
            .where((p) => addedIds.contains(p.id))
            .toList();
        return (shoppingList.copyWith(productIds: List.of(addedIds)), items);
      });
      when(
        () => collectionService.addProductsToCollection('shop-1', any()),
      ).thenAnswer((inv) async {
        addedIds.addAll(inv.positionalArguments[1] as List<String>);
      });

      await pumpDetail(tester, shoppingList);

      // Quick import appears in both toolbar and empty state.
      expect(find.text('Quick import'), findsNWidgets(2));

      await tester.tap(find.text('Quick import').last);
      await tester.pumpAndSettle();

      expect(find.text('Quick import items'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '2x Milk\nApples');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import 2 items'));
      await tester.pumpAndSettle();

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Apples'), findsOneWidget);
      // Toolbar Quick import remains accessible when non-empty.
      expect(find.text('Quick import'), findsOneWidget);
    },
  );

  testWidgets('inventory detail view does not show shopping Quick import', (
    tester,
  ) async {
    when(
      () => collectionService.getCollection('inv-1'),
    ).thenAnswer((_) async => inventory);
    when(
      () => collectionService.loadContents(inventory),
    ).thenAnswer((_) async => (inventory, <Product>[]));

    await pumpDetail(tester, inventory);

    expect(find.text('Quick import'), findsNothing);
  });
}
