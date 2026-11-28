import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/dashboard_controller.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/interfaces/i_receipt_repository.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/barcode_scanner_service.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/services/purchase_history_service.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/views/collection_list_view.dart';
import 'package:foodsavr/views/dashboard_view.dart';
import 'package:foodsavr/widgets/collection/account_kickstart_card.dart';
import 'package:foodsavr/widgets/collection/collection_card.dart';
import 'package:foodsavr/widgets/collection/collection_header.dart';
import 'package:foodsavr/widgets/collection/collection_kickstart_card.dart';
import 'package:go_router/go_router.dart';
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

class _Receipts extends Mock implements IReceiptRepository {}

class _History extends Mock implements PurchaseHistoryService {}

void main() {
  late Map<String, TestTranslationLoader> translations;
  late List<Collection> stored;

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
    await initializeDateFormatting('nb', null);
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(CollectionType.inventory);
    registerFallbackValue(
      const Collection(id: '', name: '', productIds: [], userId: ''),
    );
  });

  setUp(() async {
    await getIt.reset();
    stored = [];
    final auth = _Auth();
    when(() => auth.authStateChanges).thenAnswer((_) => const Stream.empty());
    when(() => auth.getUserId()).thenReturn('user');
    final products = _Products();
    when(() => products.getExpired(any())).thenAnswer((_) async => []);
    when(() => products.getProducts(any())).thenAnswer((_) async => []);
    when(
      () => products.getExpiringSoon(
        'user',
        expiringSoonDays: any(named: 'expiringSoonDays'),
      ),
    ).thenAnswer((_) async => []);
    final collections = _Collections();
    when(
      () => collections.getCollectionsForUser('user', type: any(named: 'type')),
    ).thenAnswer((_) async => List.of(stored));
    when(
      () => collections.resolveCounts('user', any()),
    ).thenAnswer((_) async => {});
    when(() => collections.addCollection(any())).thenAnswer((call) async {
      final added = (call.positionalArguments.single as Collection).copyWith(
        id: 'new',
      );
      stored.add(added);
      return added;
    });
    when(
      () => collections.createWithDefaultName(
        any(),
        any(),
        baseName: any(named: 'baseName'),
      ),
    ).thenAnswer((call) async {
      final type = call.positionalArguments[1] as CollectionType;
      final added = Collection(
        id: 'new${stored.length}',
        name: CollectionService.uniqueName(
          call.namedArguments[#baseName] as String,
          stored.where((c) => c.type == type).map((c) => c.name),
        ),
        userId: 'user',
        type: type,
        productIds: const [],
      );
      stored.add(added);
      return added;
    });
    when(() => collections.getCollection(any())).thenAnswer(
      (call) async =>
          stored.firstWhere((c) => c.id == call.positionalArguments.single),
    );
    when(() => collections.loadContents(any())).thenAnswer(
      (call) async =>
          (call.positionalArguments.single as Collection, <Product>[]),
    );
    final history = _History();
    when(() => history.load(any())).thenAnswer((_) async => []);
    final preferences = PreferencesController(
      auth,
      InMemoryPreferencesRepository(),
      collections,
      Logger(level: Level.off),
    );
    getIt
      ..registerSingleton<Logger>(Logger(level: Level.off))
      ..registerSingleton<IAuthService>(auth)
      ..registerSingleton<ProductService>(products)
      ..registerSingleton<CollectionService>(collections)
      ..registerSingleton<PurchaseHistoryService>(history)
      ..registerSingleton<PreferencesController>(preferences)
      ..registerSingleton<DashboardController>(
        DashboardController(
          auth,
          products,
          collections,
          preferences,
          _Receipts(),
          Logger(level: Level.off),
        ),
      );
  });

  tearDown(() => getIt.reset());

  /// Reports [cameras] as the device's cameras, a back camera by default.
  void mockCameras(
    WidgetTester tester, {
    List<Object> cameras = const [
      {'name': 'back', 'lensFacing': 'back', 'sensorOrientation': 90},
    ],
  }) {
    const channel = MethodChannel('plugins.flutter.io/camera');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => cameras,
    );
    BarcodeScannerService.refreshCameraDetection();
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      BarcodeScannerService.refreshCameraDetection();
    });
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    double width = 400,
    String language = 'en',
    List<RouteBase> routes = const [],
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font (Ahem) is far wider than the real one.
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        ...routes,
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: [Locale(language)],
        startLocale: Locale(language),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: translations[language]!,
        child: Builder(
          builder: (context) => MaterialApp.router(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps [button], which creates a collection under its default name and
  /// opens it with the title in edit mode, then closes it again.
  Future<void> createAndClose(WidgetTester tester, String button) async {
    // The dashboard sections can sit below the fold.
    await tester.ensureVisible(find.text(button));
    await tester.pumpAndSettle();
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(CollectionHeader),
        matching: find.byType(TextField),
      ),
    );
    expect(field.focusNode!.hasFocus, isTrue);
    final name = stored.last.name;
    expect(field.controller!.text, name);
    expect(
      field.controller!.selection,
      TextSelection(baseOffset: 0, extentOffset: name.length),
    );
    expect(find.byType(CollectionHeader), findsOneWidget);
    Navigator.of(tester.element(find.byType(CollectionHeader))).pop();
    await tester.pumpAndSettle();
  }

  for (final (type, title, button) in [
    (
      CollectionType.inventory,
      "You don't have an inventory yet",
      'Create Inventory',
    ),
    (
      CollectionType.shoppingList,
      "You don't have a shopping list yet",
      'Create Shopping List',
    ),
  ]) {
    testWidgets('empty ${type.name} list creates a default-named collection', (
      tester,
    ) async {
      await pump(tester, CollectionListView(typeFilter: type));

      expect(find.text(title), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);

      await createAndClose(tester, button);

      final added = stored.single;
      expect(
        added.name,
        type == CollectionType.inventory ? 'Inventory' : 'Shopping list',
      );
      expect(added.type, type);
      expect(find.byType(CollectionKickstartCard), findsNothing);
      expect(find.byType(CollectionCard), findsOneWidget);
    });
  }

  testWidgets('only the empty inventory offers catalog and barcode shortcuts', (
    tester,
  ) async {
    await pump(
      tester,
      const CollectionListView(typeFilter: CollectionType.shoppingList),
    );
    expect(find.text('Browse common products'), findsNothing);
    expect(find.text('Scan Barcode'), findsNothing);
  });

  for (final (label, path) in [
    ('Browse common products', '/dashboard/registry'),
    ('Scan Barcode', '/barcode-scan'),
  ]) {
    testWidgets('$label opens $path', (tester) async {
      mockCameras(tester);
      await pump(
        tester,
        const CollectionListView(typeFilter: CollectionType.inventory),
        routes: [GoRoute(path: path, builder: (_, _) => Text('at $path'))],
      );

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.text('at $path'), findsOneWidget);
    });
  }

  testWidgets('without a camera Scan Barcode opens the Add Product modal', (
    tester,
  ) async {
    mockCameras(tester, cameras: const []);
    await pump(
      tester,
      const CollectionListView(typeFilter: CollectionType.inventory),
    );

    await tester.tap(find.text('Scan Barcode'));
    await tester.pumpAndSettle();

    expect(find.text('Barcode or product name'), findsOneWidget);
  });

  for (final language in ['en', 'nb']) {
    for (final width in [320.0, 700.0, 1400.0]) {
      testWidgets('kickstarts fit $width px in $language', (tester) async {
        await pump(
          tester,
          const CollectionListView(typeFilter: CollectionType.inventory),
          width: width,
          language: language,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(CollectionKickstartCard), findsOneWidget);

        await pump(
          tester,
          const Scaffold(body: DashboardView()),
          width: width,
          language: language,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(AccountKickstartCard), findsOneWidget);
        expect(find.textContaining('kickstart.'), findsNothing);
      });
    }
  }

  testWidgets('empty dashboard offers each create action once', (tester) async {
    await pump(tester, const Scaffold(body: DashboardView()));

    expect(find.byType(AccountKickstartCard), findsOneWidget);
    expect(find.byType(CollectionKickstartCard), findsNWidgets(2));
    expect(find.text('Create Inventory'), findsOneWidget);
    expect(find.text('Create Shopping List'), findsOneWidget);
  });

  for (final (button, type) in [
    ('Create Inventory', CollectionType.inventory),
    ('Create Shopping List', CollectionType.shoppingList),
  ]) {
    testWidgets('dashboard kickstart: $button', (tester) async {
      await pump(tester, const Scaffold(body: DashboardView()));
      expect(find.text("Let's get you started"), findsOneWidget);

      await createAndClose(tester, button);

      expect(stored.single.type, type);
      expect(find.byType(AccountKickstartCard), findsNothing);
      // The other section keeps its own kickstart.
      expect(find.byType(CollectionKickstartCard), findsOneWidget);
      expect(find.byType(CollectionCard), findsOneWidget);
    });
  }

  testWidgets('dashboard quick action replaces the kickstart', (tester) async {
    await pump(tester, const Scaffold(body: DashboardView()));

    await tester.ensureVisible(find.text('New Shopping List'));
    await createAndClose(tester, 'New Shopping List');

    expect(find.byType(AccountKickstartCard), findsNothing);
  });

  testWidgets('a second collection gets a numbered default name', (
    tester,
  ) async {
    stored.add(
      const Collection(
        id: 'first',
        name: 'Inventory',
        productIds: [],
        userId: 'user',
      ),
    );
    await pump(
      tester,
      const CollectionListView(typeFilter: CollectionType.inventory),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(stored.map((c) => c.name), ['Inventory', 'Inventory 2']);
    expect(find.byType(CollectionHeader), findsOneWidget);
    Navigator.of(tester.element(find.byType(CollectionHeader))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(CollectionCard), findsNWidgets(2));
    expect(find.text('Inventory 2'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('a kept-alive empty list reloads when shown again', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await pump(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (_, enabled, child) =>
            TickerMode(enabled: enabled, child: child!),
        child: const CollectionListView(typeFilter: CollectionType.inventory),
      ),
    );
    expect(find.byType(CollectionKickstartCard), findsOneWidget);

    // Another tab creates a collection while this one is hidden.
    visible.value = false;
    await tester.pumpAndSettle();
    stored.add(
      const Collection(
        id: 'elsewhere',
        name: 'Elsewhere',
        productIds: [],
        userId: 'user',
      ),
    );
    visible.value = true;
    await tester.pumpAndSettle();

    expect(find.text('Elsewhere'), findsOneWidget);
    expect(find.byType(CollectionKickstartCard), findsNothing);
  });
}
