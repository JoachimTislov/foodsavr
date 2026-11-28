import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:foodsavr/features/third_party_integration/models/connection_model.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/features/third_party_integration/services/oauth_service.dart';
import 'package:foodsavr/services/secure_storage_service.dart';
import 'package:foodsavr/features/third_party_integration/interfaces/i_oauth_service.dart';
import 'package:foodsavr/constants/public_routes.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/routes/routes.dart';
import 'package:foodsavr/views/legal_document_view.dart';
import 'package:go_router/go_router.dart';
import 'package:foodsavr/controllers/preferences_controller.dart';
import 'package:foodsavr/controllers/pwa_install_controller.dart';
import 'package:foodsavr/models/collection_model.dart';
import 'package:foodsavr/utils/collection_types.dart';
import 'package:foodsavr/controllers/user_controller.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/product_service.dart';
import 'package:foodsavr/widgets/settings/settings_section.dart';
import 'package:foodsavr/widgets/settings/shorthand_toggles.dart';
import 'package:foodsavr/features/third_party_integration/oauth_controller.dart';
import 'package:foodsavr/utils/theme_notifier.dart';
import 'package:foodsavr/views/settings_view.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/in_memory_preferences_repository.dart';

class _MockUser extends Mock implements User {}

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockAuthService extends Mock implements IAuthService {}

class _MockAuthController extends Mock implements UserController {}

class _MockCollectionService extends Mock implements CollectionService {}

class _MockProductService extends Mock implements ProductService {}

class _MockGroceryStoreAuthService extends Mock implements IOAuthService {}

class _FakeSettingsPwaBridge implements PwaBridge {
  _FakeSettingsPwaBridge({required this.isInstalled});

  @override
  bool get isSupported => true;

  @override
  final bool isInstalled;

  @override
  bool get canPrompt => false;

  @override
  PwaPlatformHint get platformHint => PwaPlatformHint.standard;

  @override
  Stream<void> get onStateChanged => const Stream.empty();

  @override
  Future<PwaPromptResult> promptInstall() async => PwaPromptResult.unavailable;

  @override
  void dispose() {}
}

class _TestWrapper extends StatelessWidget {
  final Widget child;

  const _TestWrapper({required this.child});

  static Widget withRouter(BuildContext context, GoRouter router) {
    return MaterialApp.router(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routerConfig: router,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: Center(child: SizedBox(width: 1200, height: 2800, child: child)),
    );
  }
}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  setUpAll(() {
    registerFallbackValue(Provider.coop);
    // Increase surface size to avoid overflows in tests
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1200,
      2800,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDownAll(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  group('SettingsView Widget Tests', () {
    late _MockAuthService mockAuthService;
    late _MockCollectionService mockCollectionService;
    late InMemoryPreferencesRepository preferencesRepository;
    late PreferencesController preferencesController;

    setUp(() async {
      PackageInfo.setMockInitialValues(
        appName: 'foodsavr',
        packageName: 'app.foodsavr',
        version: '2.3.4',
        buildNumber: '56',
        buildSignature: '',
      );
      await getIt.reset();
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: SharedPreferencesWithCacheOptions(
          allowList: {ThemeNotifier.kThemeModeKey},
        ),
      );
      getIt.registerSingleton<SharedPreferencesWithCache>(prefs);
      getIt.registerSingleton<ThemeNotifier>(ThemeNotifier(prefs));
      getIt.registerSingleton<Logger>(Logger(level: Level.off));

      mockAuthService = _MockAuthService();
      when(
        () => mockAuthService.authStateChanges,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthService.currentUser).thenReturn(null);
      getIt.registerLazySingleton<IAuthService>(() => mockAuthService);

      mockCollectionService = _MockCollectionService();
      when(
        () => mockCollectionService.getCollectionsForUser(
          'user-1',
          type: CollectionType.inventory,
        ),
      ).thenAnswer(
        (_) async => const [
          Collection(
            id: 'inv-1',
            name: 'Fridge',
            productIds: [],
            userId: 'user-1',
          ),
          Collection(
            id: 'inv-2',
            name: 'Pantry',
            productIds: [],
            userId: 'user-1',
          ),
        ],
      );
      when(
        () => mockCollectionService.getCollectionsForUser('user-1'),
      ).thenAnswer((_) async => []);
      getIt.registerSingleton<CollectionService>(mockCollectionService);
      getIt.registerSingleton<ProductService>(_MockProductService());
      when(() => mockAuthService.getUserId()).thenReturn('user-1');
      preferencesRepository = InMemoryPreferencesRepository();
      preferencesController = PreferencesController(
        mockAuthService,
        preferencesRepository,
        mockCollectionService,
        getIt<Logger>(),
      );
      getIt.registerSingleton<PreferencesController>(preferencesController);
      final mockAuthController = _MockAuthController();
      when(() => mockAuthController.isLoading).thenReturn(false);
      when(() => mockAuthController.errorMessage).thenReturn(null);
      when(() => mockAuthController.isLogin).thenReturn(true);
      when(() => mockAuthController.successMessage).thenReturn(null);
      when(() => mockAuthController.rememberMe).thenReturn(false);
      getIt.registerSingleton<UserController>(mockAuthController);

      final groceryStoreAuthService = _MockGroceryStoreAuthService();
      when(() => groceryStoreAuthService.getConnections()).thenAnswer(
        (_) async => [
          const Connection(
            provider: Provider.coop,
            accessToken: null,
            refreshToken: null,
            idToken: null,
            accessTokenExpiration: null,
          ),
          const Connection(
            provider: Provider.rema,
            accessToken: null,
            refreshToken: null,
            idToken: null,
            accessTokenExpiration: null,
          ),
          Connection(
            provider: Provider.trumf,
            accessToken: 'token',
            refreshToken: 'token',
            idToken: 'token',
            accessTokenExpiration: DateTime.now().add(const Duration(hours: 1)),
          ),
        ],
      );
      final connections = await groceryStoreAuthService.getConnections();
      for (var connection in connections) {
        switch (connection.provider) {
          case Provider.coop:
            expect(connection.isAvailable, true);
            expect(connection.isConnected, false);
            break;
          case Provider.rema:
            expect(connection.isAvailable, true);
            expect(connection.isConnected, false);
            expect(connection.status, Status.not_configured);
            break;
          case Provider.trumf:
            expect(connection.isAvailable, true);
            expect(connection.isConnected, true);
            break;
        }
      }
      when(
        () => groceryStoreAuthService.authorize(any()),
      ).thenAnswer((_) async {});
      when(
        () => groceryStoreAuthService.fetchUserProfile(any()),
      ).thenAnswer((_) async => null);
      getIt.registerLazySingleton<IOAuthService>(() => groceryStoreAuthService);
      getIt.registerSingleton<OAuthController>(
        OAuthController(groceryStoreAuthService, getIt<Logger>()),
      );
    });

    testWidgets('settings renders at web width without a native WebView', (
      tester,
    ) async {
      await getIt.unregister<OAuthController>();
      getIt.registerLazySingleton<OAuthController>(
        () => OAuthController(
          OAuthService(getIt<Logger>(), _MockSecureStorage()),
          getIt<Logger>(),
        ),
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('BEHAVIOR'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('renders all settings sections', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('APPEARANCE'), findsOneWidget);
        expect(find.text('GROCERY INTEGRATIONS'), findsOneWidget);
        expect(find.text('PERMISSIONS'), findsOneWidget);
        expect(find.text('Camera access'), findsOneWidget);
        expect(find.text('DATA EXPORT'), findsOneWidget);
        expect(find.textContaining('Two-factor'), findsNothing);
        expect(find.text('ABOUT'), findsOneWidget);
        expect(find.text('Theme Mode'), findsOneWidget);
        expect(find.text('Language'), findsOneWidget);
        // expect(find.text('Coop'), findsOneWidget);
        // expect(find.text('Rema 1000'), findsOneWidget);
        // expect(find.text('Trumf'), findsOneWidget);
        // expect(find.byType(VectorGraphic), findsNWidgets(3));
        // expect(find.text('Not connected'), findsNothing);
      });
    });

    testWidgets('the language pill changes the language at once', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: Builder(
              builder: (context) => MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const SettingsView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LanguageTogglePill), findsOneWidget);
        expect(find.text('English'), findsOneWidget);

        await tester.tap(find.text('NO'));
        await tester.pumpAndSettle();

        // No selector opens; every section follows, behavior included.
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        for (final title in [
          'UTSEENDE',
          'ATFERD',
          'TILLATELSER',
          'DATAEKSPORT',
          'OM',
        ]) {
          expect(find.text(title), findsOneWidget, reason: title);
        }
        expect(find.text('Norsk'), findsOneWidget);

        await tester.tap(find.text('EN'));
        await tester.pumpAndSettle();
        expect(find.text('APPEARANCE'), findsOneWidget);
      });
    });

    testWidgets('the theme pill changes the theme at once', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ThemeTogglePill), findsOneWidget);
        expect(find.text('System'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.dark_mode));
        await tester.pumpAndSettle();

        expect(getIt<ThemeNotifier>().themeMode, ThemeMode.dark);
        expect(find.text('Dark'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
      });
    });

    testWidgets('keeps a fixed, centered column on wide windows', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        final section = tester.getRect(find.byType(SettingsSection).first);
        expect(section.width, SettingsSection.maxContentWidth - 32);
        expect(section.center.dx, 600);
      });
    });

    for (final locale in const [Locale('en'), Locale('nb')]) {
      testWidgets('fills a narrow window without overflow in $locale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 3200);
        addTearDown(() => tester.view.physicalSize = const Size(1200, 2800));
        final user = _MockUser();
        when(() => user.displayName).thenReturn('Kari Nordmann');
        when(
          () => user.email,
        ).thenReturn('kari.nordmann.lang.adresse@example.com');
        when(() => user.isAnonymous).thenReturn(false);
        when(() => user.photoURL).thenReturn(null);
        when(() => user.providerData).thenReturn(const []);
        when(() => mockAuthService.currentUser).thenReturn(user);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            EasyLocalization(
              supportedLocales: const [Locale('en'), Locale('nb')],
              path: 'assets/translations',
              fallbackLocale: const Locale('en'),
              startLocale: locale,
              child: Builder(
                builder: (context) => MaterialApp(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  home: const SettingsView(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(SettingsSection).first).width,
            360 - 32,
          );
        });
      });
    }

    testWidgets('settings links open the public legal modal routes', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SettingsView()),
          GoRoute(
            path: PublicRoutes.terms,
            pageBuilder: const TermsRoute().buildPage,
          ),
          GoRoute(
            path: PublicRoutes.privacy,
            pageBuilder: const PrivacyRoute().buildPage,
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: Builder(
              builder: (context) => _TestWrapper.withRouter(context, router),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final (label, title) in [
          ('Terms of Service', 'Terms of Service'),
          ('Privacy Notice', 'Privacy Notice'),
        ]) {
          await tester.tap(find.text(label));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.widgetWithText(LegalDocumentView, title), findsOneWidget);
          expect(find.byType(Dialog), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
        }
      });
    });

    testWidgets('account actions live in the profile, not in settings', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ACCOUNT'), findsNothing);
        expect(find.text('CONNECTIONS'), findsNothing);
        expect(find.text('Delete Account'), findsNothing);
        expect(find.byType(CircleAvatar), findsNothing);

        final aboutTop = tester.getTopLeft(find.text('ABOUT')).dy;
        for (final label in [
          'Terms of Service',
          'Privacy Notice',
          'App Version',
        ]) {
          expect(
            tester.getTopLeft(find.text(label)).dy,
            greaterThan(aboutTop),
            reason: label,
          );
        }
      });
    });

    testWidgets('displays app version correctly', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        // Should display app version
        expect(find.text('App Version'), findsOneWidget);
        expect(find.text('2.3.4 (56)'), findsOneWidget);
      });
    });

    testWidgets('app version tile is not tappable', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        // App version should exist
        expect(find.text('App Version'), findsOneWidget);

        // Tapping it should do nothing (no modal/dialog should appear)
        await tester.tap(find.text('App Version'));
        await tester.pumpAndSettle();

        // No dialog or bottom sheet should appear
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
      });
    });

    testWidgets('all settings icons are displayed', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        // Check that all expected icons are present
        expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
        expect(find.byIcon(Icons.language_outlined), findsOneWidget);
        expect(find.byIcon(Icons.description_outlined), findsOneWidget);
        expect(find.byIcon(Icons.privacy_tip_outlined), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });
    });

    testWidgets('shows Install App tile on web when not yet installed', (
      tester,
    ) async {
      final pwaController = PwaInstallController(
        bridge: _FakeSettingsPwaBridge(isInstalled: false),
      );
      addTearDown(pwaController.dispose);
      getIt.registerSingleton<PwaInstallController>(pwaController);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Install App'), findsOneWidget);
        expect(
          find.text('Add FoodSavr to your home screen or desktop'),
          findsOneWidget,
        );
      });
    });

    testWidgets('shows App Installed tile on web when installed', (
      tester,
    ) async {
      final pwaController = PwaInstallController(
        bridge: _FakeSettingsPwaBridge(isInstalled: true),
      );
      addTearDown(pwaController.dispose);
      getIt.registerSingleton<PwaInstallController>(pwaController);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('App Installed'), findsOneWidget);
      });
    });

    testWidgets('behavior section shows defaults and saves a new window', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('BEHAVIOR'), findsOneWidget);
        expect(find.text('6 days'), findsOneWidget);
        expect(find.text('First inventory'), findsOneWidget);

        await tester.tap(find.text('Expiring soon window'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.remove));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(preferencesController.expiringSoonDays, 5);
        expect(find.text('5 days'), findsOneWidget);
        expect(preferencesRepository.saved.last.$2.expiringSoonDays, 5);
      });
    });

    testWidgets('behavior section chooses and clears the default inventory', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Default inventory'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pantry'));
        await tester.pumpAndSettle();

        expect(preferencesController.defaultInventoryId, 'inv-2');
        expect(find.text('Pantry'), findsOneWidget);

        await tester.tap(find.text('Default inventory'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('First inventory'));
        await tester.pumpAndSettle();

        expect(preferencesController.defaultInventoryId, isNull);
        expect(find.text('First inventory'), findsOneWidget);
      });
    });

    testWidgets('behavior section is translated', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('nb'),
            child: const _TestWrapper(child: SettingsView()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ATFERD'), findsOneWidget);
        expect(find.text('Standardlager'), findsOneWidget);
      });
    });
  });
}
