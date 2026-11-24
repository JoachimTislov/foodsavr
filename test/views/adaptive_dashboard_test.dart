import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/dashboard_controller.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/views/dashboard_view.dart';
import 'package:foodsavr/widgets/common/content_constraint.dart';
import 'package:foodsavr/widgets/dashboard/overview_card.dart';
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

void main() {
  late TestTranslationLoader translations;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    translations = TestTranslationLoader();
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
          Logger(level: Level.off),
        ),
      );
  });

  tearDown(() => getIt.reset());

  Future<void> pump(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font (Ahem) is far wider than the real one.
    tester.platformDispatcher.textScaleFactorTestValue = 0.3;
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
            home: const Scaffold(body: DashboardView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Card width for `columns` columns in a grid of `gridWidth` with 12 px gaps.
  double cardWidth(double gridWidth, int columns) =>
      (gridWidth - 12 * (columns - 1)) / columns;

  double firstCardWidth(WidgetTester tester) =>
      tester.getSize(find.byType(OverviewCard).first).width;

  testWidgets('compact width keeps two columns', (tester) async {
    await pump(tester, 400);
    expect(find.text('Quick Actions').hitTestable(), findsOneWidget);
    expect(firstCardWidth(tester), cardWidth(400 - 48, 2));
  });

  testWidgets('medium width shows three fixed-height columns', (tester) async {
    await pump(tester, 700);
    expect(find.text('Quick Actions').hitTestable(), findsOneWidget);
    expect(firstCardWidth(tester), cardWidth(700 - 48, 3));
    expect(tester.getSize(find.byType(OverviewCard).first).height, 128);
  });

  testWidgets('expanded width uses a two-thirds and one-third split', (
    tester,
  ) async {
    await pump(tester, 1600);
    expect(find.text('Quick Actions').hitTestable(), findsOneWidget);
    final content = tester.getSize(find.byType(ContentConstraint));
    expect(content.width, 1600 - 64);
    final column = tester.getSize(
      find
          .descendant(
            of: find.byType(ContentConstraint),
            matching: find.byType(Column),
          )
          .first,
    );
    expect(column.width, 1120);
    // The side column holds a third of the width left after the 24 px gap.
    expect(firstCardWidth(tester), closeTo((1120 - 24) / 3, 0.01));
  });
}
