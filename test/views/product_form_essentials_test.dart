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
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:foodsavr/views/product_form_view.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_translation_loader.dart';
import '../support/fake_product_repository.dart';

class _MockAuthService extends Mock implements IAuthService {}

class _MockCollectionService extends Mock implements CollectionService {}

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

class _MockPreferencesController extends Mock
    implements PreferencesController {}

void main() {
  late TestTranslationLoader translations;
  late FakeProductRepository repository;
  late _MockCollectionService collectionService;

  const userId = 'user-1';
  const wholeMilk = Product(
    id: 'global-milk-whole',
    name: 'Whole Milk',
    description: 'Fresh whole milk, 1 l',
    userId: 'system',
    category: 'dairy',
    barcode: '7090000000011',
    isGlobal: true,
    registryType: 'global',
  );
  const apples = Product(
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
    repository = FakeProductRepository([wholeMilk, apples]);
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
    when(() => collectionService.getCollection('inv')).thenAnswer(
      (_) async => const Collection(
        id: 'inv',
        name: 'Fridge',
        productIds: [],
        userId: userId,
      ),
    );
    when(
      () => collectionService.addProductToCollection(any(), any()),
    ).thenAnswer((_) async {});

    final preferences = _MockPreferencesController();
    when(
      () => preferences.resolveDefaultInventoryId(),
    ).thenAnswer((_) async => null);
    when(() => preferences.expiringSoonDays).thenReturn(6);

    getIt
      ..registerSingleton<ProductService>(productService)
      ..registerSingleton<CollectionService>(collectionService)
      ..registerSingleton<IAuthService>(auth)
      ..registerSingleton<PreferencesController>(preferences);
  });

  tearDown(() => getIt.reset());

  Future<void> openForm(
    WidgetTester tester, {
    Product? product,
    String? collectionId,
  }) async {
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
                  onPressed: () => ProductFormView.show(
                    context,
                    product: product,
                    collectionId: collectionId,
                  ),
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
    tester.takeException();
  }

  testWidgets(
    'browsing essentials prefills name, category, description, barcode, and expiry',
    (tester) async {
      await openForm(tester, collectionId: 'inv');

      expect(find.text('Browse essentials'), findsOneWidget);
      await tester.tap(find.text('Browse essentials'));
      await tester.pumpAndSettle();

      expect(find.text('Whole Milk'), findsOneWidget);
      expect(find.text('Apples'), findsOneWidget);

      await tester.tap(find.text('Whole Milk'));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.widgetWithText(FilledButton, 'Add Product'));
      await tester.pumpAndSettle();
      tester.takeException();

      final template = repository.added.first;
      final created = repository.added.last;
      expect(template.registryType, 'personal');
      expect(created.name, 'Whole Milk');
      expect(created.description, 'Fresh whole milk, 1 l');
      expect(created.category, 'dairy');
      expect(created.barcode, '7090000000011');
      expect(created.mappedFromProductId, template.id);
      expect(created.expiries, hasLength(1));
      verify(
        () => collectionService.addProductToCollection('inv', created.id),
      ).called(1);
    },
  );

  testWidgets('one-tap quick-add creates and adds essential immediately', (
    tester,
  ) async {
    await openForm(tester, collectionId: 'inv');

    await tester.tap(find.text('Browse essentials'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Quick add').first);
    await tester.pumpAndSettle();

    final created = repository.added.last;
    expect(created.name, 'Whole Milk');
    expect(created.barcode, '7090000000011');
    verify(
      () => collectionService.addProductToCollection('inv', created.id),
    ).called(1);
    expect(find.text('Essentials'), findsNothing);
  });

  testWidgets('hides Browse essentials when editing an existing product', (
    tester,
  ) async {
    const existing = Product(
      id: 'p1',
      name: 'Milk',
      description: '',
      userId: userId,
    );
    await openForm(tester, product: existing);

    expect(find.text('Browse essentials'), findsNothing);
  });
}
