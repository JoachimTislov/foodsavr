import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/adaptive_layout.dart';
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

class _Auth extends Mock implements IAuthService {}

class _Products extends Mock implements ProductService {}

class _Collections extends Mock implements CollectionService {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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
        child: const MaterialApp(home: Scaffold(body: DashboardView())),
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
    expect(firstCardWidth(tester), cardWidth(400 - 48, 2));
  });

  testWidgets('medium width keeps two columns', (tester) async {
    await pump(tester, 700);
    expect(firstCardWidth(tester), cardWidth(700 - 48, 2));
  });

  testWidgets('expanded width shows three columns in a bounded column', (
    tester,
  ) async {
    await pump(tester, 1600);
    expect(firstCardWidth(tester), cardWidth(AdaptiveLayout.pageMaxWidth, 3));
    final content = tester.getSize(find.byType(ContentConstraint));
    expect(content.width, 1600 - 48);
    final column = tester.getSize(
      find
          .descendant(
            of: find.byType(ContentConstraint),
            matching: find.byType(Column),
          )
          .first,
    );
    expect(column.width, AdaptiveLayout.pageMaxWidth);
  });
}
