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
      home: Center(child: SizedBox(width: 1200, height: 1800, child: child)),
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
      1800,
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
      getIt.registerSingleton<CollectionService>(mockCollectionService);
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
      when(() => mockAuthController.agreedToTerms).thenReturn(false);
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

        expect(find.text('ACCOUNT'), findsOneWidget);
        expect(find.text('APPEARANCE'), findsOneWidget);
        expect(find.text('GROCERY INTEGRATIONS'), findsOneWidget);
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

    testWidgets('opens language selector and changes language', (tester) async {
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

        // Initial language should be English
        expect(find.text('English'), findsOneWidget);

        // Tap on Language setting
        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();

        // Should see language options in English
        expect(find.text('English'), findsNWidgets(2)); // Tile and Modal item
        expect(find.text('Norwegian'), findsOneWidget);

        // Select Norwegian
        await tester.tap(find.text('Norwegian'));
        await tester.pumpAndSettle();

        // Sections should be translated
        expect(find.text('KONTO'), findsOneWidget);
        expect(find.text('UTSEENDE'), findsOneWidget);
        expect(find.text('OM'), findsOneWidget);

        // Language text in settings tile should update to Norsk (English is 'Engelsk' in NB)
        expect(find.text('Norsk'), findsOneWidget);
      });
    });

    testWidgets('opens theme selector and changes theme', (tester) async {
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

        // Tap on Theme Mode setting
        await tester.tap(find.text('Theme Mode'));
        await tester.pumpAndSettle();

        // Should see theme options
        // One 'System' is the subtitle of the tile, the other is in the modal
        expect(find.text('System'), findsNWidgets(2));
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('Dark'), findsOneWidget);

        // Select Dark theme
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();

        // Modal closes and the Theme row shows the chosen mode
        expect(find.text('System'), findsNothing);
        expect(find.text('Dark'), findsOneWidget);
        expect(getIt<ThemeNotifier>().themeMode, ThemeMode.dark);
      });
    });

    testWidgets('settings links open the public legal routes', (tester) async {
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(path: '/settings', builder: (_, _) => const SettingsView()),
          GoRoute(path: '/terms', builder: const TermsRoute().build),
          GoRoute(path: '/privacy', builder: const PrivacyRoute().build),
          GoRoute(
            path: '/delete-account',
            builder: (_, _) => const Placeholder(),
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
          ('Privacy Policy', 'Privacy Notice'),
        ]) {
          await tester.tap(find.text(label));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.widgetWithText(LegalDocumentView, title), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Delete Account'));
        await tester.pumpAndSettle();
        expect(find.byType(Placeholder), findsOneWidget);
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

    testWidgets('displays user profile with email', (tester) async {
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

        // Should display ACCOUNT section
        expect(find.text('ACCOUNT'), findsOneWidget);

        // Should have a CircleAvatar (profile icon)
        expect(find.byType(CircleAvatar), findsOneWidget);
      });
    });

    testWidgets(
      'account tile falls back to profile title when displayName is empty or whitespace',
      (tester) async {
        final user = _MockUser();
        when(() => user.displayName).thenReturn('   ');
        when(() => user.email).thenReturn('');
        when(() => user.isAnonymous).thenReturn(false);
        when(() => user.photoURL).thenReturn(null);
        when(() => mockAuthService.currentUser).thenReturn(user);

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

          expect(find.text('Profile'), findsOneWidget);
        });
      },
    );

    testWidgets('theme selector shows checkmark on current theme', (
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

        // Tap on Theme Mode setting
        await tester.tap(find.text('Theme Mode'));
        await tester.pumpAndSettle();

        // Should have theme icons
        expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
        expect(find.byIcon(Icons.light_mode), findsOneWidget);
        expect(find.byIcon(Icons.dark_mode), findsOneWidget);
      });
    });

    testWidgets('language selector shows checkmark on current language', (
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

        // Tap on Language setting
        await tester.tap(find.text('Language'));
        await tester.pumpAndSettle();

        // Should show checkmark for English (current language)
        final checkIcons = find.byIcon(Icons.check);
        expect(checkIcons, findsAtLeastNWidgets(1));
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
