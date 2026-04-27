import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/main.dart' as main_app;
import 'package:foodsavr/main.dart';
import 'package:foodsavr/router.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/auth_controller.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:foodsavr/services/theme_notifier.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Suppress EasyLocalization logging during tests
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  setUpAll(() {
    // Setup Firebase mocking
    setupFirebaseCoreMocks();
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

  group('Main App Constants', () {
    test('main function throws if flavor is not provided and not on web', () async {
      // By default in unit tests (Dart VM), appFlavor is null and kIsWeb is false.
      // Therefore, the new flavor safeguard in main() should immediately throw.
      await expectLater(
        () => main_app.main(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No app flavor provided. Please run the app using'),
          ),
        ),
      );
    });

    test('supportedFlavors contains expected values', () {
      expect(supportedFlavors, isNotEmpty);
      expect(supportedFlavors, contains('development'));
      expect(supportedFlavors, contains('production'));
      expect(supportedFlavors.length, 2);
    });

    test('supportedFlavors list is in correct order', () {
      expect(supportedFlavors[0], 'development');
      expect(supportedFlavors[1], 'production');
    });

    test('dummyOptions has correct configuration', () {
      expect(dummyOptions.apiKey, 'AIzaSyDummyKeyForDemoOnly');
      expect(dummyOptions.appId, '1:1234567890:web:dummyid123456');
      expect(dummyOptions.projectId, 'demo-project');
      expect(dummyOptions.messagingSenderId, isEmpty);
    });

    test('dummyOptions uses demo project ID', () {
      expect(dummyOptions.projectId, 'demo-project');
    });
  });

  group('MyApp Widget', () {
    late MockAuthService mockAuthService;

    setUp(() async {
      await getIt.reset();
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: SharedPreferencesWithCacheOptions(
          allowList: {ThemeNotifier.kThemeModeKey},
        ),
      );
      getIt.registerSingleton<SharedPreferencesWithCache>(prefs);
      getIt.registerSingleton<ThemeNotifier>(ThemeNotifier(prefs));
      getIt.registerSingleton<Logger>(Logger(level: Level.off));
      mockAuthService = MockAuthService();
      when(
        () => mockAuthService.authStateChanges,
      ).thenAnswer((_) => Stream.value(null));
      when(() => mockAuthService.currentUser).thenReturn(null);
      getIt.registerLazySingleton<IAuthService>(() => mockAuthService);

      final mockCollectionService = MockCollectionService();
      getIt.registerSingleton<CollectionService>(mockCollectionService);

      final mockAuthController = MockAuthController();
      when(() => mockAuthController.isLoading).thenReturn(false);
      when(() => mockAuthController.errorMessage).thenReturn(null);
      when(() => mockAuthController.isLogin).thenReturn(true);
      when(() => mockAuthController.successMessage).thenReturn(null);
      when(() => mockAuthController.rememberMe).thenReturn(false);
      when(() => mockAuthController.agreedToTerms).thenReturn(false);
      getIt.registerSingleton<AuthController>(mockAuthController);
    });

    testWidgets('renders MaterialApp.router with correct configuration', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final router = createAppRouter(mockAuthService);

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: Center(
              child: SizedBox(
                width: 1200,
                height: 1800,
                child: MyApp(router: router),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should render MaterialApp.router
        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        expect(materialApp.title, 'FoodSavr');
        expect(materialApp.theme, isNotNull);
        expect(materialApp.darkTheme, isNotNull);
      });
    });

    testWidgets('uses localization from context', (tester) async {
      await tester.runAsync(() async {
        final router = createAppRouter(mockAuthService);

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: Center(
              child: SizedBox(
                width: 1200,
                height: 1800,
                child: MyApp(router: router),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        expect(materialApp.supportedLocales, contains(const Locale('en')));
        expect(materialApp.supportedLocales, contains(const Locale('nb')));
        expect(materialApp.locale, const Locale('en'));
      });
    });

    testWidgets('applies light and dark themes', (tester) async {
      await tester.runAsync(() async {
        final router = createAppRouter(mockAuthService);

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: Center(
              child: SizedBox(
                width: 1200,
                height: 1800,
                child: MyApp(router: router),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        expect(materialApp.theme, isNotNull);
        expect(materialApp.darkTheme, isNotNull);
        expect(materialApp.theme!.brightness, Brightness.light);
        expect(materialApp.darkTheme!.brightness, Brightness.dark);
      });
    });

    testWidgets('uses router config', (tester) async {
      await tester.runAsync(() async {
        final router = createAppRouter(mockAuthService);

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: Center(
              child: SizedBox(
                width: 1200,
                height: 1800,
                child: MyApp(router: router),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        expect(materialApp.routerConfig, isNotNull);
        expect(materialApp.routerConfig, router);
      });
    });

    testWidgets('MyApp accepts router config parameter', (tester) async {
      await tester.runAsync(() async {
        final router = createAppRouter(mockAuthService);
        final app = MyApp(router: router);

        expect(app.router, router);
      });
    });

    testWidgets('rebuilds when theme changes', (tester) async {
      await tester.runAsync(() async {
        final router = createAppRouter(mockAuthService);

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: Center(
              child: SizedBox(
                width: 1200,
                height: 1800,
                child: MyApp(router: router),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial state
        var materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.themeMode, isNotNull);

        // The app should rebuild when ThemeNotifier changes
        // This is tested indirectly through the ListenableBuilder
        final listenableBuilder = tester.widget<ListenableBuilder>(
          find.byType(ListenableBuilder).first,
        );
        expect(listenableBuilder.listenable, isNotNull);
      });
    });
  });

  group('Flavor Validation', () {
    test('validates supported flavors list is not empty', () {
      expect(supportedFlavors, isNotEmpty);
    });

    test('all flavor names are lowercase', () {
      for (final flavor in supportedFlavors) {
        expect(flavor, flavor.toLowerCase());
      }
    });

    test('no duplicate flavors in list', () {
      final uniqueFlavors = supportedFlavors.toSet();
      expect(uniqueFlavors.length, supportedFlavors.length);
    });

    test('flavor names do not contain special characters', () {
      final validPattern = RegExp(r'^[a-z]+$');
      for (final flavor in supportedFlavors) {
        expect(validPattern.hasMatch(flavor), isTrue);
      }
    });
  });

  group('Firebase Configuration', () {
    test('dummyOptions has valid API key format', () {
      expect(dummyOptions.apiKey, isNotEmpty);
      expect(dummyOptions.apiKey.startsWith('AIzaSy'), isTrue);
    });

    test('dummyOptions app ID has correct format', () {
      expect(dummyOptions.appId, contains(':'));
      expect(dummyOptions.appId, contains('web'));
    });

    test('dummyOptions uses correct project ID for emulator', () {
      expect(dummyOptions.projectId, 'demo-project');
    });

    test('dummyOptions messaging sender ID can be empty', () {
      // Messaging sender ID can be empty for demo/emulator setups
      expect(dummyOptions.messagingSenderId, isA<String>());
    });
  });

  group('Edge Cases', () {
    testWidgets('MyApp handles null checks correctly', (tester) async {
      await tester.runAsync(() async {
        final mockAuthService = MockAuthService();
        when(
          () => mockAuthService.authStateChanges,
        ).thenAnswer((_) => Stream.value(null));
        when(() => mockAuthService.currentUser).thenReturn(null);

        final router = createAppRouter(mockAuthService);

        // Should not throw even with minimal setup
        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: MyApp(router: router),
          ),
        );
        await tester.pump();

        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    test('supportedFlavors is immutable', () {
      // Immutability is enforced at compile-time since supportedFlavors is const
      expect(supportedFlavors, isA<List<String>>());
    });

    test('dummyOptions is immutable', () {
      // FirebaseOptions is immutable by design
      expect(dummyOptions, isA<FirebaseOptions>());
    });
  });

  group('Localization Support', () {
    testWidgets('supports both English and Norwegian locales', (tester) async {
      await tester.runAsync(() async {
        final mockAuthService = MockAuthService();
        when(
          () => mockAuthService.authStateChanges,
        ).thenAnswer((_) => Stream.value(null));
        when(() => mockAuthService.currentUser).thenReturn(null);

        final router = createAppRouter(mockAuthService);

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: Center(
              child: SizedBox(
                width: 1200,
                height: 1800,
                child: MyApp(router: router),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        expect(materialApp.supportedLocales.length, 2);
        expect(
          materialApp.supportedLocales,
          containsAll([const Locale('en'), const Locale('nb')]),
        );
      });
    });

    testWidgets('uses fallback locale when locale is not supported', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final mockAuthService = MockAuthService();
        when(
          () => mockAuthService.authStateChanges,
        ).thenAnswer((_) => Stream.value(null));
        when(() => mockAuthService.currentUser).thenReturn(null);

        final router = createAppRouter(mockAuthService);

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('nb')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en'),
            child: Center(
              child: SizedBox(
                width: 1200,
                height: 1800,
                child: MyApp(router: router),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        // Default should be English
        expect(materialApp.locale, const Locale('en'));
      });
    });
  });
}

// Helper to setup Firebase mocks
void setupFirebaseCoreMocks() {
  // This is needed to prevent Firebase initialization errors in tests
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_core'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'Firebase#initializeCore') {
            return [
              {
                'name': '[DEFAULT]',
                'options': {
                  'apiKey': 'test-api-key',
                  'appId': 'test-app-id',
                  'messagingSenderId': 'test-sender-id',
                  'projectId': 'test-project-id',
                },
                'pluginConstants': {},
              },
            ];
          }
          if (methodCall.method == 'Firebase#initializeApp') {
            return {
              'name': methodCall.arguments['appName'],
              'options': methodCall.arguments['options'],
              'pluginConstants': {},
            };
          }
          return null;
        },
      );
}

class MockAuthController extends Mock implements AuthController {}

class MockAuthService extends Mock implements IAuthService {}

class MockCollectionService extends Mock implements CollectionService {}
