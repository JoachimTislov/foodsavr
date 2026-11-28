import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:foodsavr/widgets/collection/quick_import_shopping_dialog.dart';
import 'package:foodsavr/widgets/product/product_icon.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_translation_loader.dart';
import '../../support/fake_product_repository.dart';

class _MockAuthService extends Mock implements IAuthService {}

class _MockCollectionService extends Mock implements CollectionService {}

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

void main() {
  late TestTranslationLoader translations;
  late FakeProductRepository repository;
  late _MockCollectionService collectionService;

  const userId = 'user-1';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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
    when(
      () => collectionService.addProductsToCollection(any(), any()),
    ).thenAnswer((_) async {});

    getIt
      ..registerSingleton<ProductService>(productService)
      ..registerSingleton<CollectionService>(collectionService)
      ..registerSingleton<IAuthService>(auth);
  });

  tearDown(() => getIt.reset());

  Future<bool?> openDialog(WidgetTester tester, {String? collectionId}) async {
    bool? result;
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
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await QuickImportShoppingDialog.show(
                      context,
                      collectionId: collectionId,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets(
    'live previews parsed items, allows removing, and imports remaining',
    (tester) async {
      await openDialog(tester, collectionId: 'list-1');

      await tester.enterText(
        find.byType(TextField),
        '2x Milk, Bread\n- [x] Butter\n- Apples',
      );
      await tester.pumpAndSettle();

      expect(find.text('3 items ready to import'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('x2'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
      expect(find.text('Apples'), findsOneWidget);
      expect(find.text('Butter'), findsNothing);
      expect(find.byType(ProductIcon), findsNWidgets(3));

      // Remove "Bread" (second item).
      await tester.tap(find.byTooltip('Remove item').at(1));
      await tester.pumpAndSettle();

      expect(find.text('2 items ready to import'), findsOneWidget);
      expect(find.text('Bread'), findsNothing);

      await tester.tap(find.text('Import 2 items'));
      await tester.pumpAndSettle();

      expect(repository.added, hasLength(2));
      expect(repository.added[0].name, 'Milk');
      expect(repository.added[0].nonExpiringQuantity, 2);
      expect(repository.added[0].category, 'dairy');
      expect(repository.added[0].registryType, 'current');
      expect(repository.added[1].name, 'Apples');
      expect(repository.added[1].nonExpiringQuantity, 1);
      expect(repository.added[1].category, 'fruits');

      verify(
        () => collectionService.addProductsToCollection('list-1', [
          repository.added[0].id,
          repository.added[1].id,
        ]),
      ).called(1);
    },
  );

  testWidgets('loads user shopping lists when collectionId is omitted', (
    tester,
  ) async {
    when(
      () => collectionService.getCollectionsForUser(
        userId,
        type: CollectionType.shoppingList,
      ),
    ).thenAnswer(
      (_) async => const [
        Collection(
          id: 'shop-1',
          name: 'Weekend Shop',
          userId: userId,
          type: CollectionType.shoppingList,
          productIds: [],
        ),
      ],
    );

    await openDialog(tester);

    expect(find.text('Weekend Shop'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Coffee');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import 1 item'));
    await tester.pumpAndSettle();

    verify(
      () => collectionService.addProductsToCollection('shop-1', [
        repository.added.single.id,
      ]),
    ).called(1);
  });

  testWidgets(
    'shows helpful message and disables import when no shopping lists exist',
    (tester) async {
      when(
        () => collectionService.getCollectionsForUser(
          userId,
          type: CollectionType.shoppingList,
        ),
      ).thenAnswer((_) async => const []);

      await openDialog(tester);

      expect(
        find.text('Create a shopping list first to import items.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Milk');
      await tester.pumpAndSettle();

      final importButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(importButton.onPressed, isNull);
    },
  );
}
