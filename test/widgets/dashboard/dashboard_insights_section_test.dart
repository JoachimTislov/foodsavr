import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/models/dashboard_insights.dart';
import 'package:foodsavr/services/barcode_scanner_service.dart';
import 'package:foodsavr/widgets/dashboard/dashboard_insights_section.dart';
import 'package:foodsavr/widgets/dashboard/insight_tile.dart';
import 'package:go_router/go_router.dart';

import '../../support/localized_app.dart';

void main() {
  setUpAll(setUpLocalizedApp);

  const filled = DashboardInsights(
    productCount: 12,
    expiringSoonCount: 3,
    expiredCount: 2,
    hasExpiries: true,
    shoppingListCount: 1,
    shoppingListItemCount: 7,
    receiptCount: 4,
    recentReceiptItemCount: 9,
  );

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

  Future<GoRouter> pump(
    WidgetTester tester,
    DashboardInsights insights, {
    double width = 400,
    String language = 'en',
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: DashboardInsightsSection(
                insights: insights,
                onChanged: () async {},
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/dashboard/my-products',
          builder: (_, _) => const Text('products'),
        ),
        GoRoute(
          path: '/dashboard/receipts',
          builder: (_, _) => const Text('receipts'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpLocalized(tester, null, routerConfig: router, language: language);
    return router;
  }

  String path(GoRouter router) =>
      router.routeInformationProvider.value.uri.toString();

  testWidgets('shows a figure per statistic when data exists', (tester) async {
    await pump(tester, filled);

    expect(tester.takeException(), isNull);
    expect(find.byType(InsightTile), findsNWidgets(5));
    for (final text in [
      '12',
      '3',
      '2',
      '7',
      '4',
      '9 items in the last 30 days',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text('Add Product'), findsNothing);
    expect(find.text('Add Expiry'), findsNothing);
    expect(find.text('Scan Receipt'), findsNothing);
    expect(find.text('New Shopping List'), findsNothing);
  });

  testWidgets('the tiles link to their filtered lists', (tester) async {
    final router = await pump(tester, filled);

    await tester.tap(find.text('Expiring Soon'));
    await tester.pumpAndSettle();
    expect(path(router), '/dashboard/my-products?status=expiring');

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expired'));
    await tester.pumpAndSettle();
    expect(path(router), '/dashboard/my-products?status=expired');

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receipts registered'));
    await tester.pumpAndSettle();
    expect(path(router), '/dashboard/receipts');
  });

  testWidgets('without data every tile offers its enriching action', (
    tester,
  ) async {
    mockCameras(tester, const [
      {'name': 'back', 'lensFacing': 'back', 'sensorOrientation': 90},
    ]);
    await pump(tester, const DashboardInsights());

    expect(tester.takeException(), isNull);
    // One tile covers both expiry statistics.
    expect(find.byType(InsightTile), findsNWidgets(4));
    expect(find.text('Expired'), findsNothing);
    for (final text in [
      'Add Product',
      'Add Expiry',
      'New Shopping List',
      'Scan Receipt',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
  });

  testWidgets('the empty receipt tile explains a missing camera', (
    tester,
  ) async {
    mockCameras(tester, const []);
    await pump(tester, const DashboardInsights());

    expect(find.text('No camera available'), findsOneWidget);
    expect(find.text('Scan Receipt'), findsNothing);
  });

  for (final language in ['en', 'nb']) {
    for (final width in [320.0, 700.0, 1400.0]) {
      testWidgets('tiles fit $width px in $language', (tester) async {
        await pump(tester, filled, width: width, language: language);

        expect(tester.takeException(), isNull);
        expect(find.textContaining('dashboard.'), findsNothing);
        for (final tile in find.byType(InsightTile).evaluate()) {
          final rect = tester.getRect(find.byWidget(tile.widget));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
      });
    }
  }
}
