import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/dashboard_controller.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/barcode_scanner_service.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/views/collection_detail_view.dart';
import 'package:foodsavr/views/dashboard_view.dart';
import 'package:foodsavr/widgets/collection/account_kickstart_card.dart';
import 'package:foodsavr/widgets/collection/collection_card.dart';
import 'package:foodsavr/widgets/collection/collection_kickstart_card.dart';
import 'package:foodsavr/widgets/dashboard/dashboard_collections_section.dart';
import 'package:foodsavr/widgets/dashboard/expired_items_section.dart';
import 'package:foodsavr/widgets/dashboard/expiring_item_card.dart';
import 'package:foodsavr/widgets/dashboard/expiring_soon_section.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/in_memory_preferences_repository.dart';
import '../helpers/test_translation_loader.dart';

class _Auth extends Mock implements IAuthService {}

class _Products extends Mock implements ProductService {}

class _Collections extends Mock implements CollectionService {}

Product _expiringIn(String id, int days) {
  final now = DateTime.now();
  return Product(
    id: id,
    name: 'Product $id',
    description: '',
    userId: 'user',
    expiries: [
      ExpiryEntry(
        quantity: 1,
        expirationDate: DateTime(now.year, now.month, now.day + days),
      ),
    ],
  );
}

void main() {
  late Map<String, TestTranslationLoader> translations;
  late _Products products;
  late _Collections collections;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(
      const Collection(id: '', name: '', productIds: [], userId: ''),
    );
    translations = {
      'en': TestTranslationLoader(),
      'nb': TestTranslationLoader('nb'),
    };
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    EasyLocalization.logger.enableLevels = [];
    await initializeDateFormatting('en', null);
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    await getIt.reset();
    final auth = _Auth();
    when(() => auth.authStateChanges).thenAnswer((_) => const Stream.empty());
    when(() => auth.getUserId()).thenReturn('user');
    products = _Products();
    when(() => products.getExpired(any())).thenAnswer((_) async => []);
    when(
      () => products.getExpiringSoon(
        'user',
        expiringSoonDays: any(named: 'expiringSoonDays'),
      ),
    ).thenAnswer((_) async => []);
    // A started account; the empty one is covered by the kickstart tests.
    when(() => products.getProducts('user')).thenAnswer(
      (_) async => [
        const Product(id: 'p', name: 'Rice', description: '', userId: 'user'),
      ],
    );
    collections = _Collections();
    when(
      () => collections.getCollectionsForUser('user', type: any(named: 'type')),
    ).thenAnswer((_) async => []);
    final preferences = PreferencesController(
      auth,
      InMemoryPreferencesRepository(),
      collections,
      Logger(level: Level.off),
    );
    getIt
      ..registerSingleton<PreferencesController>(preferences)
      ..registerSingleton<IAuthService>(auth)
      ..registerSingleton<ProductService>(products)
      ..registerSingleton<CollectionService>(collections)
      ..registerSingleton<DashboardController>(
        DashboardController(
          auth,
          products,
          collections,
          preferences,
          Logger(level: Level.off),
        ),
      );
  });

  tearDown(() => getIt.reset());

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode? mode,
    Locale locale = const Locale('en'),
    double width = 400,
    double textScale = 0.3,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: [locale],
        startLocale: locale,
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: translations[locale.languageCode]!,
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            themeMode: mode,
            theme: ThemeData(colorSchemeSeed: const Color(0xFF13C8EC)),
            darkTheme: ThemeData(
              colorSchemeSeed: const Color(0xFF13C8EC),
              brightness: Brightness.dark,
            ),
            home: const Scaffold(body: DashboardView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('upcoming card shows expired status once its entries expire', (
    tester,
  ) async {
    // The list was loaded before midnight; the only entry has since expired.
    when(
      () => products.getExpiringSoon(
        'user',
        expiringSoonDays: any(named: 'expiringSoonDays'),
      ),
    ).thenAnswer((_) async => [_expiringIn('stale', -1)]);

    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(ExpiringSoonSection),
        matching: find.text('Expired 1 day ago'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows expired items, oldest first, above expiring soon', (
    tester,
  ) async {
    final mixed = _expiringIn('mixed', -1).copyWith(
      expiries: [
        ..._expiringIn('past', -1).expiries,
        ..._expiringIn('later', 4).expiries,
        ..._expiringIn('tomorrow', 1).expiries,
      ],
    );
    when(
      () => products.getExpired('user'),
    ).thenAnswer((_) async => [_expiringIn('ten', -10), mixed]);
    when(
      () => products.getExpiringSoon(
        'user',
        expiringSoonDays: any(named: 'expiringSoonDays'),
      ),
    ).thenAnswer((_) async => [mixed, _expiringIn('three', 3)]);

    await pump(tester);

    final expiredCards = find.descendant(
      of: find.byType(ExpiredItemsSection),
      matching: find.byType(ExpiringItemCard),
    );
    expect(expiredCards, findsNWidgets(2));
    expect(
      find.descendant(
        of: expiredCards.first,
        matching: find.text('Product ten'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: expiredCards.last,
        matching: find.text('Expired 1 day ago'),
      ),
      findsOneWidget,
    );
    final soonCards = find.descendant(
      of: find.byType(ExpiringSoonSection),
      matching: find.byType(ExpiringItemCard),
    );
    expect(soonCards, findsNWidgets(2));
    expect(find.text('Product mixed'), findsNWidgets(2));
    expect(
      find.descendant(of: soonCards.first, matching: find.text('1d remaining')),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ExpiringSoonSection),
        matching: find.text('Product three'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byType(ExpiredItemsSection)).dy,
      lessThan(tester.getTopLeft(find.byType(ExpiringSoonSection)).dy),
    );
  });

  for (final (language, count, countLabel, daysLabel) in [
    ('en', 1, '1 expired item', 'Expired 1 day ago'),
    ('en', 2, '2 expired items', 'Expired 2 days ago'),
    ('nb', 1, '1 utgått produkt', 'Utgått for 1 dag siden'),
    ('nb', 2, '2 utgåtte produkter', 'Utgått for 2 dager siden'),
  ]) {
    testWidgets('pluralizes expired count and days for $count in $language', (
      tester,
    ) async {
      when(() => products.getExpired('user')).thenAnswer(
        (_) async => [
          if (count == 2) _expiringIn('older', -3),
          _expiringIn('old', -count),
        ],
      );

      await pump(tester, locale: Locale(language));

      expect(find.bySemanticsLabel(countLabel), findsOneWidget);
      expect(find.text(daysLabel), findsOneWidget);
    });
  }

  testWidgets('long expiry labels wrap at narrow widths and 2x text', (
    tester,
  ) async {
    when(
      () => products.getExpired('user'),
    ).thenAnswer((_) async => [_expiringIn('ancient', -1000)]);

    await pump(tester, width: 320, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('Expired 1000 days ago'), findsOneWidget);
  });

  testWidgets('hides the expired section when nothing has expired', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(ExpiredItemsSection), findsNothing);
    expect(find.text('Expired'), findsNothing);
    expect(find.byType(ExpiringItemCard), findsNothing);
  });

  void stubCollections() {
    const stored = [
      Collection(
        id: 'fridge',
        name: 'Fridge',
        productIds: ['a', 'b'],
        userId: 'user',
      ),
      Collection(
        id: 'weekend',
        name: 'Weekend',
        productIds: ['c'],
        userId: 'user',
        type: CollectionType.shoppingList,
      ),
    ];
    when(
      () => collections.getCollectionsForUser('user', type: any(named: 'type')),
    ).thenAnswer((_) async => stored);
    when(
      () => collections.resolveCounts('user', stored),
    ).thenAnswer((_) async => {'fridge': 7, 'weekend': 3});
  }

  Finder section(CollectionType type) => find.byWidgetPredicate(
    (widget) => widget is DashboardCollectionsSection && widget.type == type,
  );

  for (final width in [390.0, 1280.0]) {
    testWidgets('lists inventories and shopping lists at $width px', (
      tester,
    ) async {
      stubCollections();

      await pump(tester, width: width);

      expect(tester.takeException(), isNull);
      for (final (type, title, name, count, addTooltip) in [
        (
          CollectionType.inventory,
          'My Inventory',
          'Fridge',
          '7 items',
          'Add Inventory',
        ),
        (
          CollectionType.shoppingList,
          'Shopping List',
          'Weekend',
          '3 items',
          'Add Shopping List',
        ),
      ]) {
        for (final text in [title, name, count]) {
          expect(
            find.descendant(of: section(type), matching: find.text(text)),
            findsWidgets,
          );
        }
        expect(
          find.descendant(
            of: section(type),
            matching: find.byType(CollectionCard),
          ),
          findsOneWidget,
        );
        expect(find.byTooltip(addTooltip), findsOneWidget);
      }
      expect(find.byType(CollectionKickstartCard), findsNothing);
      expect(find.byType(AccountKickstartCard), findsNothing);
    });
  }

  for (final (addTooltip, title) in [
    ('Add Inventory', 'Add Inventory'),
    ('Add Shopping List', 'Add Shopping List'),
  ]) {
    testWidgets('the $addTooltip button opens a modal form', (tester) async {
      getIt.registerSingleton<Logger>(Logger(level: Level.off));
      stubCollections();
      await pump(tester);

      await tester.ensureVisible(find.byTooltip(addTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(addTooltip));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(title)),
        findsOneWidget,
      );
    });
  }

  testWidgets('tapping a collection opens its detail view', (tester) async {
    stubCollections();
    when(() => collections.resolveContents(any())).thenAnswer(
      (call) async => (
        call.positionalArguments.single as Collection,
        <Product>[],
        authoritative: true,
      ),
    );
    when(() => collections.loadContents(any())).thenAnswer(
      (call) async =>
          (call.positionalArguments.single as Collection, <Product>[]),
    );
    await pump(tester);

    await tester.ensureVisible(find.text('Weekend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekend'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CollectionDetailView>(find.byType(CollectionDetailView))
          .collection
          .id,
      'weekend',
    );
  });

  testWidgets('each empty section shows its own kickstart', (tester) async {
    await pump(tester);

    for (final (type, title) in [
      (CollectionType.inventory, "You don't have an inventory yet"),
      (CollectionType.shoppingList, "You don't have a shopping list yet"),
    ]) {
      expect(
        find.descendant(of: section(type), matching: find.text(title)),
        findsOneWidget,
      );
    }
    expect(find.byType(CollectionCard), findsNothing);
    // A started account is not welcomed again.
    expect(find.byType(AccountKickstartCard), findsNothing);
  });

  testWidgets('Register Expiry starts with the expiry date', (tester) async {
    // No camera, so the flow asks with the date picker.
    const channel = MethodChannel('plugins.flutter.io/camera');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => <Object>[],
    );
    BarcodeScannerService.refreshCameraDetection();
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      BarcodeScannerService.refreshCameraDetection();
    });
    // The date picker header overflows at the tiny default test scale.
    await pump(tester, textScale: 0.5);

    await tester.tap(find.text('Register Expiry'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('renders the expired section in dark mode', (tester) async {
    when(
      () => products.getExpired('user'),
    ).thenAnswer((_) async => [_expiringIn('old', -3)]);

    await pump(tester, mode: ThemeMode.dark);

    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Expired 3 days ago'), findsOneWidget);
  });
}
