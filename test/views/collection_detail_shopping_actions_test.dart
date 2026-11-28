import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/services/purchase_history_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/utils/shelf_life.dart';
import 'package:foodsavr/validation/validators/product_model_validator.dart';
import 'package:foodsavr/views/collection_detail_view.dart';
import 'package:foodsavr/widgets/collection/shopping_list_item_card.dart';
import 'package:foodsavr/widgets/product/view_mode_toggle.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_translation_loader.dart';
import '../support/fake_product_repository.dart';

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
  const userId = 'user-1';
  const milk = Product(
    id: 'milk',
    name: 'Milk',
    description: '',
    userId: userId,
    nonExpiringQuantity: 1,
  );
  const shoppingList = Collection(
    id: 'shop-1',
    name: 'Weekly Groceries',
    userId: userId,
    type: CollectionType.shoppingList,
    productIds: ['milk'],
  );
  const inventory = Collection(
    id: 'inv-1',
    name: 'Fridge',
    userId: userId,
    type: CollectionType.inventory,
    productIds: [],
  );

  late TestTranslationLoader translations;
  late FakeProductRepository repository;
  late _MockCollectionService collections;
  late PurchaseHistoryService history;
  late _FakePreferences preferences;
  late List<String> members;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(_FakeCollection());
    translations = TestTranslationLoader();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    EasyLocalization.logger.enableBuildModes = [];
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    repository = FakeProductRepository([milk]);
    members = ['milk'];
    collections = _MockCollectionService();
    history = PurchaseHistoryService(Logger(level: Level.off));
    preferences = _FakePreferences();
    when(
      () => collections.getCollection('shop-1'),
    ).thenAnswer((_) async => shoppingList.copyWith(productIds: members));
    when(() => collections.loadContents(any())).thenAnswer(
      (_) async => (
        shoppingList.copyWith(productIds: members),
        repository.products.where((p) => members.contains(p.id)).toList(),
      ),
    );
    when(
      () => collections.getCollectionsForUser(
        userId,
        type: CollectionType.inventory,
      ),
    ).thenAnswer((_) async => [inventory]);
    when(
      () => collections.removeProductFromCollection(
        'shop-1',
        'milk',
        onRejected: any(named: 'onRejected'),
      ),
    ).thenAnswer((_) async => members = []);
    when(
      () => collections.addProductToCollection('inv-1', 'milk'),
    ).thenAnswer((_) async {});

    getIt
      ..registerSingleton<ProductService>(
        ProductService(
          repository,
          ProductModelValidator(),
          _MockShelfLifeService(),
          Logger(level: Level.off),
        ),
      )
      ..registerSingleton<CollectionService>(collections)
      ..registerSingleton<PreferencesController>(preferences)
      ..registerSingleton<PurchaseHistoryService>(history);
  });

  tearDown(() {
    preferences.dispose();
    return getIt.reset();
  });

  Future<void> pumpList(WidgetTester tester) async {
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
            home: const CollectionDetailView(collection: shoppingList),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> move(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fridge'));
    await tester.pumpAndSettle();
  }

  testWidgets('shopping lists offer no view mode toggle', (tester) async {
    await pumpList(tester);

    expect(find.byType(ViewModeToggle), findsNothing);
  });

  testWidgets('a bought item is recorded once with readable history', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(await history.load(userId), hasLength(1));
    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('1 · Added by hand · '), findsOneWidget);
    expect(find.textContaining('manual'), findsNothing);
  });

  testWidgets('a removal rejected later withdraws the purchase', (
    tester,
  ) async {
    void Function()? reject;
    when(
      () => collections.removeProductFromCollection(
        'shop-1',
        'milk',
        onRejected: any(named: 'onRejected'),
      ),
    ).thenAnswer((invocation) async {
      reject = invocation.namedArguments[#onRejected] as void Function()?;
      members = [];
    });
    await pumpList(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(await history.load(userId), hasLength(1));

    // Firestore rolls the removal back before reporting the rejection.
    members = ['milk'];
    reject!();
    await tester.pumpAndSettle();

    expect(await history.load(userId), isEmpty);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('Added by hand'), findsNothing);
  });

  testWidgets('a failed removal records no purchase', (tester) async {
    when(
      () => collections.removeProductFromCollection(
        'shop-1',
        'milk',
        onRejected: any(named: 'onRejected'),
      ),
    ).thenAnswer((_) async => throw StateError('rejected'));
    await pumpList(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(await history.load(userId), isEmpty);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('quantity controls wait for the pending change', (tester) async {
    final removal = Completer<void>();
    when(
      () => collections.removeProductFromCollection(
        'shop-1',
        'milk',
        onRejected: any(named: 'onRejected'),
      ),
    ).thenAnswer((_) => removal.future);
    await pumpList(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
          .onPressed,
      isNull,
    );

    members = [];
    removal.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('quantity changes apply to the stored product', (tester) async {
    await pumpList(tester);
    // Changed elsewhere after the row was loaded.
    repository.products[0] = milk.copyWith(nonExpiringQuantity: 5);

    await tester.tap(
      find.descendant(
        of: find.byType(ShoppingListItemCard),
        matching: find.widgetWithIcon(IconButton, Icons.add),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.products.single.quantity, 6);
  });

  testWidgets('a failed move keeps the item and is reported', (tester) async {
    when(
      () => collections.moveProduct(
        'shop-1',
        'inv-1',
        'milk',
        onRejected: any(named: 'onRejected'),
      ),
    ).thenAnswer((_) async => throw StateError('rejected'));
    await pumpList(tester);

    await move(tester);

    expect(find.text('Could not move the product. Try again.'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('a move rejected later is reported and reloaded', (tester) async {
    void Function()? reject;
    when(
      () => collections.moveProduct(
        'shop-1',
        'inv-1',
        'milk',
        onRejected: any(named: 'onRejected'),
      ),
    ).thenAnswer((invocation) async {
      reject = invocation.namedArguments[#onRejected] as void Function()?;
      members = [];
    });
    await pumpList(tester);
    await move(tester);
    expect(find.byType(Checkbox), findsNothing);

    members = ['milk'];
    reject!();
    await tester.pumpAndSettle();

    expect(find.text('Could not move the product. Try again.'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('a failed duplicate leaves no stray copy', (tester) async {
    when(
      () => collections.addProductToCollection('inv-1', any()),
    ).thenAnswer((_) async => throw StateError('rejected'));
    await pumpList(tester);

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    expect(repository.added, hasLength(1));
    expect(repository.products.map((p) => p.id), ['milk']);
    expect(find.textContaining('Could not duplicate'), findsOneWidget);
  });

  testWidgets('re-adding a deleted product offers to create it again', (
    tester,
  ) async {
    await history.record(userId, [
      milk.copyWith(id: 'gone', name: 'Eggs', nonExpiringQuantity: 6),
    ], PurchaseSource.manual);
    when(() => collections.addProductToCollection('shop-1', any())).thenAnswer((
      invocation,
    ) async {
      members = [...members, invocation.positionalArguments[1] as String];
    });
    await pumpList(tester);

    await tester.tap(find.text('Re-add'));
    await tester.pumpAndSettle();
    expect(find.text('Create Eggs again with quantity 6?'), findsOneWidget);
    expect(repository.added, isEmpty);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(repository.added.single.name, 'Eggs');
    expect(repository.added.single.quantity, 6);
    expect(members, ['milk', repository.added.single.id]);
  });

  for (final menu in ['popup', 'long-press']) {
    testWidgets('a failed delete from the $menu menu is reported', (
      tester,
    ) async {
      repository.deleteError = StateError('rejected');
      await pumpList(tester);

      if (menu == 'popup') {
        await tester.tap(find.byType(PopupMenuButton<String>).last);
      } else {
        await tester.longPress(find.text('Milk').first);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).onChanged,
        isNotNull,
      );
    });
  }
}
