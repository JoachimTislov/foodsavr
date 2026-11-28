import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/features/third_party_integration/interfaces/i_oauth_service.dart';
import 'package:foodsavr/features/third_party_integration/models/connection_model.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/features/third_party_integration/oauth_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/models/dashboard_insights.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/views/batch_expiry_view.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/barcode_scanner_service.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/views/receipt_scan_view.dart';
import 'package:foodsavr/widgets/dashboard/dashboard_action_button.dart';
import 'package:foodsavr/widgets/dashboard/dashboard_entry_points.dart';
import 'package:foodsavr/widgets/settings/data_export_section.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/in_memory_preferences_repository.dart';
import '../../support/localized_app.dart';

class _Auth extends Mock implements IAuthService {}

class _Products extends Mock implements ProductService {}

class _Collections extends Mock implements CollectionService {}

class _OAuth extends Mock implements IOAuthService {}

void main() {
  setUpAll(() async {
    registerFallbackValue(CollectionType.inventory);
    await setUpLocalizedApp();
  });

  late _OAuth oauth;
  late _Collections collections;
  var changes = 0;

  setUp(() async {
    await getIt.reset();
    changes = 0;
    final auth = _Auth();
    when(() => auth.authStateChanges).thenAnswer((_) => const Stream.empty());
    when(() => auth.getUserId()).thenReturn('user');
    collections = _Collections();
    when(
      () => collections.getCollectionsForUser('user', type: any(named: 'type')),
    ).thenAnswer((_) async => <Collection>[]);
    oauth = _OAuth();
    when(oauth.getConnections).thenAnswer((_) async => []);
    getIt
      ..registerSingleton<Logger>(Logger(level: Level.off))
      ..registerSingleton<IAuthService>(auth)
      ..registerSingleton<ProductService>(_Products())
      ..registerSingleton<CollectionService>(collections)
      ..registerSingleton<PreferencesController>(
        PreferencesController(
          auth,
          InMemoryPreferencesRepository(),
          collections,
          Logger(level: Level.off),
        ),
      );
  });

  tearDown(() => getIt.reset());

  /// Reports [cameras] as the device's cameras.
  void mockCameras(WidgetTester tester, List<Object> cameras) {
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

  const backCamera = {
    'name': 'back',
    'lensFacing': 'back',
    'sensorOrientation': 90,
  };

  Future<GoRouter> pump(
    WidgetTester tester, {
    double width = 1280,
    String language = 'en',
    Set<DashboardAction> hidden = const {},
    bool canTransfer = false,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font (Ahem) is far wider than the real one.
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: DashboardEntryPoints(
                onChanged: () async => changes++,
                hidden: hidden,
                canTransfer: canTransfer,
              ),
            ),
          ),
        ),
        GoRoute(path: '/settings', builder: (_, _) => const Text('settings')),
        GoRoute(
          path: '/dashboard/registry',
          builder: (_, _) => const Text('registry'),
        ),
        GoRoute(
          path: '/dashboard/transfer',
          builder: (_, _) => const Text('transfer'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpLocalized(tester, null, routerConfig: router, language: language);
    return router;
  }

  DashboardActionButton button(WidgetTester tester, String label) =>
      tester.widget(find.widgetWithText(DashboardActionButton, label));

  testWidgets('without a camera Scan Receipt is disabled and explained', (
    tester,
  ) async {
    mockCameras(tester, const []);
    await pump(tester);

    expect(button(tester, 'Scan Receipt').onTap, isNull);
    expect(find.text('No camera available'), findsOneWidget);
    expect(
      find.byTooltip(
        'Receipt scanning needs a connected camera that is allowed in '
        'Settings.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Scan Receipt'));
    await tester.pumpAndSettle();
    expect(find.byType(ReceiptScanView), findsNothing);
  });

  testWidgets('desktop platforms never enable Scan Receipt', (tester) async {
    mockCameras(tester, const [backCamera]);
    await pump(tester);

    expect(button(tester, 'Scan Receipt').onTap, isNull);
    expect(find.text('No camera available'), findsOneWidget);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('with a camera Scan Receipt opens the scanner', (tester) async {
    mockCameras(tester, const [backCamera]);
    await pump(tester);

    expect(button(tester, 'Scan Receipt').onTap, isNotNull);
    expect(find.text('No camera available'), findsNothing);

    await tester.tap(find.text('Scan Receipt'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ReceiptScanView), findsOneWidget);
  });

  testWidgets('Import opens the quick-import modal on the dashboard', (
    tester,
  ) async {
    final router = await pump(tester);

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Quick import items'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(changes, 0);
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('Export opens a closable modal at $width px', (tester) async {
      await pump(tester, width: width);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DataExportSection), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(DataExportSection), findsNothing);
    });
  }

  for (final (label, type) in [
    ('New Shopping List', CollectionType.shoppingList),
    ('New Inventory', CollectionType.inventory),
  ]) {
    testWidgets('$label creates a collection of its type', (tester) async {
      when(
        () => collections.createWithDefaultName(
          any(),
          any(),
          baseName: any(named: 'baseName'),
        ),
      ).thenThrow(StateError('offline'));
      await pump(tester);

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      verify(
        () => collections.createWithDefaultName(
          'user',
          type,
          baseName: any(named: 'baseName'),
        ),
      ).called(1);
      expect(find.byType(Dialog), findsNothing);
    });
  }

  testWidgets('Add Expiry opens the batch expiry session', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Add Expiry'));
    await tester.pumpAndSettle();

    expect(find.byType(BatchExpiryView), findsOneWidget);
  });

  testWidgets('actions offered by an insight tile are not repeated', (
    tester,
  ) async {
    await pump(tester, hidden: DashboardAction.values.toSet());

    for (final label in [
      'Add Product',
      'Add Expiry',
      'Scan Receipt',
      'New Shopping List',
    ]) {
      expect(find.text(label), findsNothing);
    }
    for (final label in ['Import', 'Export', 'New Inventory']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('the registry opens from the quick actions', (tester) async {
    final router = await pump(tester);

    await tester.tap(find.text('Product registry'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/dashboard/registry',
    );
  });

  testWidgets('Transfer is offered only with several inventories', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Transfer'), findsNothing);

    await pump(tester, canTransfer: true);
    expect(find.text('Transfer'), findsOneWidget);
  });

  testWidgets('Add Product opens a modal where no camera can scan', (
    tester,
  ) async {
    mockCameras(tester, const []);
    final router = await pump(tester);

    await tester.tap(find.text('Add Product'));
    await tester.pumpAndSettle();

    expect(find.text('Barcode or product name'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('integrations are hidden without a controller', (tester) async {
    await pump(tester);

    expect(find.text('Integrations'), findsNothing);
  });

  testWidgets('integrations are hidden when none is configured', (
    tester,
  ) async {
    getIt.registerSingleton(OAuthController(oauth, Logger(level: Level.off)));
    await pump(tester);

    expect(find.text('Integrations'), findsNothing);
  });

  testWidgets('integrations are hidden when they cannot be loaded', (
    tester,
  ) async {
    when(oauth.getConnections).thenThrow(StateError('storage'));
    getIt.registerSingleton(OAuthController(oauth, Logger(level: Level.off)));
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Integrations'), findsNothing);
  });

  testWidgets('a configured integration opens Settings', (tester) async {
    when(oauth.getConnections).thenAnswer(
      (_) async => const [
        Connection(
          provider: Provider.coop,
          accessToken: null,
          refreshToken: null,
          idToken: null,
          accessTokenExpiration: null,
        ),
      ],
    );
    getIt.registerSingleton(OAuthController(oauth, Logger(level: Level.off)));
    final router = await pump(tester);

    await tester.tap(find.text('Integrations'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/settings');
  });

  for (final language in ['en', 'nb']) {
    for (final width in [320.0, 700.0, 1400.0]) {
      testWidgets('quick actions fit $width px in $language', (tester) async {
        await pump(tester, width: width, language: language);

        expect(tester.takeException(), isNull);
        expect(find.byType(DashboardActionButton), findsNWidgets(8));
        expect(find.textContaining('dashboard.'), findsNothing);
      });
    }
  }
}
