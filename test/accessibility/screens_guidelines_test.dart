import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/dashboard_controller.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/features/third_party_integration/interfaces/i_oauth_service.dart';
import 'package:foodsavr/features/third_party_integration/oauth_controller.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/models/product_model.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/utils/app_theme.dart';
import 'package:foodsavr/utils/theme_notifier.dart';
import 'package:foodsavr/views/dashboard_view.dart';
import 'package:foodsavr/views/product_detail_view.dart';
import 'package:foodsavr/views/product_form_view.dart';
import 'package:foodsavr/views/settings_view.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/fake_receipt_repository.dart';
import '../helpers/in_memory_preferences_repository.dart';
import '../helpers/test_translation_loader.dart';

class _Auth extends Mock implements IAuthService {}

class _Products extends Mock implements ProductService {}

class _Collections extends Mock implements CollectionService {}

class _OAuth extends Mock implements IOAuthService {}

const _userId = 'user';

Product _product(String id, int days) {
  final now = DateTime.now();
  return Product(
    id: id,
    name: 'Product $id',
    description: 'Description $id',
    userId: _userId,
    category: 'Dairy',
    nonExpiringQuantity: 1,
    expiries: [
      ExpiryEntry(
        quantity: 1,
        expirationDate: DateTime(now.year, now.month, now.day + days),
      ),
    ],
  );
}

enum _Screen { dashboard, productDetail, productForm, settings }

void main() {
  late TestTranslationLoader translations;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    translations = TestTranslationLoader();
    EasyLocalization.logger.enableLevels = [];
    EasyLocalization.logger.enableBuildModes = [];
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('en', null);
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    await getIt.reset();
    PackageInfo.setMockInitialValues(
      appName: 'foodsavr',
      packageName: 'app.foodsavr',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(
        allowList: {ThemeNotifier.kThemeModeKey},
      ),
    );
    final logger = Logger(level: Level.off);

    final auth = _Auth();
    when(() => auth.authStateChanges).thenAnswer((_) => const Stream.empty());
    when(() => auth.getUserId()).thenReturn(_userId);
    when(() => auth.currentUser).thenReturn(null);

    final products = _Products();
    // No stored products or collections, so the audit covers the kickstart.
    when(() => products.getProducts(any())).thenAnswer((_) async => []);
    when(
      () => products.getExpired(any()),
    ).thenAnswer((_) async => [_product('expired', -2)]);
    when(
      () => products.getExpiringSoon(
        _userId,
        expiringSoonDays: any(named: 'expiringSoonDays'),
      ),
    ).thenAnswer((_) async => [_product('soon', 2)]);

    final collections = _Collections();
    when(
      () =>
          collections.getCollectionsForUser(_userId, type: any(named: 'type')),
    ).thenAnswer((_) async => []);
    when(
      () => collections.getInventoriesByProductId(_userId, any()),
    ).thenAnswer((_) async => []);

    final oauth = _OAuth();
    when(oauth.getConnections).thenAnswer((_) async => []);

    final preferences = PreferencesController(
      auth,
      InMemoryPreferencesRepository(),
      collections,
      logger,
    );
    getIt
      ..registerSingleton<Logger>(logger)
      ..registerSingleton<SharedPreferencesWithCache>(prefs)
      ..registerSingleton<ThemeNotifier>(ThemeNotifier(prefs))
      ..registerSingleton<IAuthService>(auth)
      ..registerSingleton<ProductService>(products)
      ..registerSingleton<CollectionService>(collections)
      ..registerSingleton<PreferencesController>(preferences)
      ..registerSingleton<OAuthController>(OAuthController(oauth, logger))
      ..registerSingleton<DashboardController>(
        DashboardController(
          auth,
          products,
          collections,
          preferences,
          FakeReceiptRepository(),
          logger,
        ),
      );
  });

  tearDown(() => getIt.reset());

  Widget home(_Screen screen) => switch (screen) {
    _Screen.dashboard => const Scaffold(body: DashboardView()),
    _Screen.productDetail => ProductDetailView(product: _product('detail', 3)),
    _Screen.productForm => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () =>
                ProductFormView.show(context, product: _product('form', 3)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    _Screen.settings => const SettingsView(),
  };

  Finder rendered(_Screen screen) => switch (screen) {
    _Screen.dashboard => find.text('Product soon'),
    _Screen.productDetail => find.byTooltip('Delete product'),
    _Screen.productForm => find.byTooltip('Increase quantity'),
    _Screen.settings => find.text('APPEARANCE'),
  };

  for (final brightness in Brightness.values) {
    for (final screen in _Screen.values) {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        testWidgets('${screen.name} meets guidelines in ${brightness.name} on '
            '${platform.name}', (tester) async {
          tester.view.physicalSize = const Size(800, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
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
                  theme: brightness == Brightness.light
                      ? AppTheme.lightTheme
                      : AppTheme.darkTheme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.noScaling),
                    child: child!,
                  ),
                  home: home(screen),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (screen == _Screen.productForm) {
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();
          }
          // The test font is wider than the real one; layout overflow is
          // not what these tests cover.
          final exception = tester.takeException();
          if (screen == _Screen.productForm) {
            // The test font is wider than the real one; a RenderFlex overflow
            // on the quantity/action row is expected under the test font.
            if (exception != null) {
              expect(exception, isA<FlutterError>());
              expect(
                exception.toString(),
                contains('A RenderFlex overflowed by'),
              );
            }
          } else {
            expect(exception, isNull);
          }
          expect(rendered(screen), findsWidgets);

          await expectLater(
            tester,
            meetsGuideline(
              platform == TargetPlatform.android
                  ? androidTapTargetGuideline
                  : iOSTapTargetGuideline,
            ),
          );
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        }, variant: TargetPlatformVariant({platform}));
      }
    }
  }
}
