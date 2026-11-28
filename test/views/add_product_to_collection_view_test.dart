import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:foodsavr/views/add_product_to_collection_view.dart';
import 'package:foodsavr/widgets/product/product_icon.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_translation_loader.dart';
import '../support/fake_product_repository.dart';

class _MockAuthService extends Mock implements IAuthService {}

class _MockCollectionService extends Mock implements CollectionService {}

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

void main() {
  late TestTranslationLoader translations;
  late FakeProductRepository repository;
  late _MockCollectionService collectionService;

  const userId = 'user-1';
  const personalItem = Product(
    id: 'personal-oat',
    name: 'Oat Barista',
    description: 'Favorite oat milk',
    userId: userId,
    category: 'dairy',
    registryType: 'personal',
  );
  const essentialMilk = Product(
    id: 'global-milk',
    name: 'Whole Milk',
    description: 'Fresh whole milk, 1 l',
    userId: 'system',
    category: 'dairy',
    barcode: '7090000000011',
    isGlobal: true,
    registryType: 'global',
  );
  const essentialApples = Product(
    id: 'global-apples',
    name: 'Apples',
    description: 'Fresh apples, 1 kg',
    userId: 'system',
    category: 'fruits',
    barcode: '7090000000103',
    isGlobal: true,
    registryType: 'global',
  );

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
    repository = FakeProductRepository([
      personalItem,
      essentialMilk,
      essentialApples,
    ]);
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

  testWidgets('groups Your products and Essentials with search and 2-tap add', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
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
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      AddProductToCollectionView.show(context, 'shop-1'),
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

    expect(find.text('Oat Barista'), findsOneWidget);
    expect(find.text('Whole Milk'), findsOneWidget);
    expect(find.text('Apples'), findsOneWidget);
    expect(find.byType(ProductIcon), findsNWidgets(3));

    // Search filters across both sections.
    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pumpAndSettle();
    expect(find.text('Apples'), findsOneWidget);
    expect(find.text('Whole Milk'), findsNothing);

    // Tap essential + tap Add (2 taps).
    await tester.tap(find.text('Apples'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 item'));
    await tester.pumpAndSettle();

    expect(repository.added, hasLength(1));
    expect(repository.added.single.name, 'Apples');
    expect(repository.added.single.nonExpiringQuantity, 1);
    expect(repository.added.single.barcode, '7090000000103');
    verify(
      () => collectionService.addProductsToCollection('shop-1', [
        repository.added.single.id,
      ]),
    ).called(1);
  });
}
