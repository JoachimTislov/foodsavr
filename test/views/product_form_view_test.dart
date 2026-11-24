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

import '../support/fake_product_repository.dart';

class _MockAuthService extends Mock implements IAuthService {}

class _MockCollectionService extends Mock implements CollectionService {}

class _MockShelfLifeService extends Mock implements ShelfLifeService {}

class _MockPreferencesController extends Mock
    implements PreferencesController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  const userId = 'user-1';
  late FakeProductRepository repository;
  late _MockCollectionService collectionService;
  late ProductService productService;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();

    repository = FakeProductRepository();
    final shelfLife = _MockShelfLifeService();
    when(() => shelfLife.estimateExpiration(any())).thenReturn(null);
    productService = ProductService(
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

    getIt.registerSingleton<ProductService>(productService);
    getIt.registerSingleton<CollectionService>(collectionService);
    getIt.registerSingleton<IAuthService>(auth);
    // No default inventory: a new product without a collection stays
    // standalone, as before preferences existed.
    final preferences = _MockPreferencesController();
    when(
      () => preferences.resolveDefaultInventoryId(),
    ).thenAnswer((_) async => null);
    when(() => preferences.expiringSoonDays).thenReturn(6);
    getIt.registerSingleton<PreferencesController>(preferences);
  });

  setUpAll(() {
    registerFallbackValue(
      const Product(id: 'x', name: 'x', description: '', userId: 'u'),
    );
  });

  // The test font is wider than the real one and overflows the expiry row;
  // layout overflow is not what these tests cover.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    tester.takeException();
  }

  Future<void> openForm(
    WidgetTester tester, {
    Product? product,
    Product? prefill,
    String? collectionId,
  }) async {
    // Translations load through real asynchronous I/O.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en'),
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => ProductFormView.show(
                      context,
                      product: product,
                      prefill: prefill,
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
    });
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  const scanned = Product(
    id: '',
    name: '',
    description: '',
    userId: userId,
    nonExpiringQuantity: 1,
    barcode: '0000000999001',
  );

  testWidgets('A: unknown barcode saves a new product into the collection', (
    tester,
  ) async {
    await openForm(tester, prefill: scanned, collectionId: 'inv');

    await tester.enterText(find.byType(TextFormField).first, 'Oat drink');
    await tester.tap(find.text('Create'));
    await settle(tester);

    final current = repository.added.last;
    expect(repository.updated, isEmpty);
    expect(current.name, 'Oat drink');
    expect(current.barcode, '0000000999001');
    expect(current.id, isNotEmpty);
    expect(current.registryType, 'current');
    verify(
      () => collectionService.addProductToCollection('inv', current.id),
    ).called(1);
    expect(find.text('Create'), findsNothing);
  });

  testWidgets('a retry after a failed assignment creates no second product', (
    tester,
  ) async {
    var attempts = 0;
    when(
      () => collectionService.addProductToCollection(any(), any()),
    ).thenAnswer((_) async {
      if (attempts++ == 0) throw Exception('offline');
    });
    await openForm(tester, prefill: scanned, collectionId: 'inv');
    await tester.enterText(find.byType(TextFormField).first, 'Oat drink');

    await tester.tap(find.text('Create'));
    await settle(tester);
    final addedAfterFailure = repository.added.length;
    await tester.tap(find.text('Create'));
    await settle(tester);

    expect(repository.added.length, addedAfterFailure);
    expect(attempts, 2);
    expect(find.text('Create'), findsNothing);
  });

  testWidgets('B: editing keeps barcode, image and tags; rescan increments', (
    tester,
  ) async {
    final known = Product(
      id: 'p1',
      name: 'Milk',
      description: '',
      userId: userId,
      nonExpiringQuantity: 1,
      barcode: '0000001234567',
      imageUrl: 'https://img/milk.png',
      tags: const ['en:organic'],
      registryType: 'current',
      mappedFromProductId: 'personal-1',
    );
    repository.products.add(known);
    await openForm(tester, product: known);

    await tester.enterText(find.byType(TextFormField).first, 'Oat milk');
    await tester.tap(find.text('Save'));
    await settle(tester);

    final saved = repository.updated.single;
    expect(saved.name, 'Oat milk');
    expect(saved.barcode, known.barcode);
    expect(saved.imageUrl, known.imageUrl);
    expect(saved.tags, known.tags);
    expect(saved.registryType, 'current');
    expect(saved.mappedFromProductId, 'personal-1');
    expect(repository.added, isEmpty);

    final rescan = await productService.addOrIncrementByBarcode(
      userId: userId,
      barcode: '1234567',
    );
    expect(rescan.matchedExisting, isTrue);
    expect(rescan.product.id, 'p1');
    expect(repository.added, isEmpty);
    expect(repository.products, hasLength(1));
  });

  testWidgets('failed validation performs no write', (tester) async {
    await openForm(tester, prefill: scanned, collectionId: 'inv');

    await tester.tap(find.text('Create'));
    await settle(tester);

    expect(find.text('Please enter product name'), findsOneWidget);
    expect(repository.writes, 0);
    verifyNever(() => collectionService.addProductToCollection(any(), any()));
  });

  testWidgets('a failed save shows the localized error', (tester) async {
    repository.addError = Exception('offline');
    await openForm(tester, prefill: scanned);

    await tester.enterText(find.byType(TextFormField).first, 'Oat drink');
    await tester.tap(find.text('Create'));
    await settle(tester);

    expect(
      find.text('Failed to save product: Exception: offline'),
      findsOneWidget,
    );
  });

  testWidgets('choosing Dairy pre-fills an estimated expiry', (tester) async {
    await openForm(tester, prefill: scanned, collectionId: 'inv');

    await tester.enterText(find.byType(TextFormField).first, 'Oat drink');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('Dairy').last);
    await settle(tester);
    await tester.tap(find.text('Create'));
    await settle(tester);

    final expiries = repository.added.last.expiries;
    expect(expiries, hasLength(1));
    final days = expiries.single.expirationDate
        .difference(DateUtils.dateOnly(DateTime.now()))
        .inDays;
    expect(days, 10);
  });

  testWidgets('a removed suggestion stays removed after a category change', (
    tester,
  ) async {
    await openForm(tester, prefill: scanned, collectionId: 'inv');

    await tester.enterText(find.byType(TextFormField).first, 'Oat drink');
    Future<void> choose(String category) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settle(tester);
      await tester.tap(find.text(category).last);
      await settle(tester);
    }

    await choose('Dairy');
    final remove = find.byIcon(Icons.delete_outline);
    await tester.ensureVisible(remove);
    await settle(tester);
    await tester.tap(remove);
    await settle(tester);
    await choose('Bakery');
    await choose('Dairy');
    await tester.tap(find.text('Create'));
    await settle(tester);

    expect(repository.added.last.expiries, isEmpty);
  });
}
