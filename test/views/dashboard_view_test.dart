import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/dashboard_controller.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/views/dashboard_view.dart';
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

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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
    final collections = _Collections();
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
  }) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 0.3;
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

  testWidgets('hides the expired section when nothing has expired', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(ExpiredItemsSection), findsNothing);
    expect(find.text('Expired'), findsNothing);
    expect(find.byType(ExpiringItemCard), findsNothing);
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
