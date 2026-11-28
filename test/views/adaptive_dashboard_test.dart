import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/adaptive_layout.dart';
import 'package:foodsavr/controllers/dashboard_controller.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/views/dashboard_view.dart';
import 'package:foodsavr/widgets/common/content_constraint.dart';
import 'package:foodsavr/widgets/dashboard/dashboard_action_button.dart';
import 'package:foodsavr/widgets/dashboard/dashboard_entry_points.dart';
import 'package:foodsavr/widgets/dashboard/dashboard_insights_section.dart';
import 'package:foodsavr/widgets/dashboard/insight_tile.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/fake_receipt_repository.dart';
import '../helpers/in_memory_preferences_repository.dart';
import '../helpers/test_translation_loader.dart';

class _Auth extends Mock implements IAuthService {}

class _Products extends Mock implements ProductService {}

class _Collections extends Mock implements CollectionService {}

void main() {
  late TestTranslationLoader translations;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    translations = TestTranslationLoader();
    // Use the SDK’s Material font so 2x tests reflect actual text widths.
    final flutterArtifacts = File(
      Platform.resolvedExecutable,
    ).parent.parent.parent;
    final roboto = File.fromUri(
      flutterArtifacts.uri.resolve('material_fonts/Roboto-Regular.ttf'),
    );
    await (FontLoader(
      'TestRoboto',
    )..addFont(roboto.readAsBytes().then(ByteData.sublistView))).load();
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
    final products = _Products();
    when(
      () => products.getExpiringSoon(
        'user',
        expiringSoonDays: any(named: 'expiringSoonDays'),
      ),
    ).thenAnswer((_) async => []);
    when(() => products.getExpired(any())).thenAnswer((_) async => []);
    // A started account; the empty one is covered by the kickstart tests.
    when(() => products.getProducts('user')).thenAnswer(
      (_) async => [
        const Product(id: 'p', name: 'Rice', description: '', userId: 'user'),
      ],
    );
    final collections = _Collections();
    when(
      () => collections.getCollectionsForUser('user', type: any(named: 'type')),
    ).thenAnswer((_) async => []);
    getIt
      ..registerSingleton<IAuthService>(auth)
      ..registerSingleton<ProductService>(products)
      ..registerSingleton<CollectionService>(collections)
      ..registerSingleton<DashboardController>(
        DashboardController(
          auth,
          products,
          collections,
          PreferencesController(
            auth,
            InMemoryPreferencesRepository(),
            collections,
            Logger(level: Level.off),
          ),
          FakeReceiptRepository(),
          Logger(level: Level.off),
        ),
      );
  });

  tearDown(() => getIt.reset());

  Future<void> pump(
    WidgetTester tester,
    double width, {
    double textScale = 0.3,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font (Ahem) is far wider than the real one.
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        assetLoader: translations,
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: textScale == 2 ? ThemeData(fontFamily: 'TestRoboto') : null,
            home: const Scaffold(body: DashboardView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final contentColumn = find
      .descendant(
        of: find.byType(ContentConstraint),
        matching: find.byType(Column),
      )
      .first;

  for (final width in [400.0, 700.0, 1600.0]) {
    testWidgets('one column capped at the page width at $width px', (
      tester,
    ) async {
      await pump(tester, width);

      expect(tester.takeException(), isNull);
      expect(find.text('Quick Actions').hitTestable(), findsOneWidget);
      final column = tester.getRect(contentColumn);
      expect(column.width, lessThanOrEqualTo(AdaptiveLayout.pageMaxWidth));
      // Insights and actions stack: no widget sits beside another section.
      final insights = tester.getRect(find.byType(DashboardInsightsSection));
      final actions = tester.getRect(find.byType(DashboardEntryPoints));
      expect(insights.bottom, lessThanOrEqualTo(actions.top));
      expect(insights.left, actions.left);
    });
  }

  testWidgets('quick actions and insights keep clear of each other at 2x', (
    tester,
  ) async {
    await pump(tester, 360, textScale: 2);

    expect(tester.takeException(), isNull);
    for (final type in [InsightTile, DashboardActionButton]) {
      final rects = [
        for (final element in find.byType(type).evaluate())
          tester.getRect(find.byWidget(element.widget)),
      ];
      for (final rect in rects) {
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
      }
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse);
        }
      }
    }
  });

  testWidgets('an action shown by an insight tile is not in Quick Actions', (
    tester,
  ) async {
    // Rice has no expiry, and there is no receipt or shopping list.
    await pump(tester, 700);

    for (final label in ['Add Expiry', 'Scan Receipt', 'New Shopping List']) {
      expect(find.text(label), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DashboardInsightsSection),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    // The product statistic has data, so its action stays a quick action.
    expect(
      find.descendant(
        of: find.byType(DashboardEntryPoints),
        matching: find.text('Add Product'),
      ),
      findsOneWidget,
    );
  });
}
