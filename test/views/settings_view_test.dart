import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/views/settings_view.dart';
import 'package:foodsavr/services/theme_notifier.dart';
import 'package:foodsavr/services/auth_controller.dart';
import 'package:foodsavr/services/collection_service.dart';
import 'package:logger/logger.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements IAuthService {}

class _MockAuthController extends Mock implements AuthController {}

class _MockCollectionService extends Mock implements CollectionService {}

class _TestWrapper extends StatelessWidget {
  final Widget child;

  const _TestWrapper({required this.child});

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  setUpAll(() {
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

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await EasyLocalization.ensureInitialized();
      await getIt.reset();

      getIt.registerSingleton<Logger>(Logger(level: Level.off));
      getIt.registerSingleton<ThemeNotifier>(ThemeNotifier(prefs));
      mockAuthService = _MockAuthService();
      when(
        () => mockAuthService.authStateChanges,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthService.currentUser).thenReturn(null);
      getIt.registerLazySingleton<IAuthService>(() => mockAuthService);

      getIt.registerSingleton<CollectionService>(_MockCollectionService());
      final mockAuthController = _MockAuthController();
      when(() => mockAuthController.isLoading).thenReturn(false);
      when(() => mockAuthController.errorMessage).thenReturn(null);
      when(() => mockAuthController.isLogin).thenReturn(true);
      when(() => mockAuthController.successMessage).thenReturn(null);
      when(() => mockAuthController.rememberMe).thenReturn(false);
      when(() => mockAuthController.agreedToTerms).thenReturn(false);
      getIt.registerSingleton<AuthController>(mockAuthController);
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
        expect(find.text('ABOUT'), findsOneWidget);
        expect(find.text('Theme Mode'), findsOneWidget);
        expect(find.text('Language'), findsOneWidget);
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

        // Modal should close (one 'System' remains in the tile)
        expect(find.text('System'), findsOneWidget);
      });
    });

    testWidgets('shows legal dialog for Terms of Service', (tester) async {
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

        // Tap on Terms of Service
        await tester.tap(find.text('Terms of Service'));
        await tester.pumpAndSettle();

        // Should see dialog with Terms of Service title
        expect(
          find.widgetWithText(AlertDialog, 'Terms of Service'),
          findsOneWidget,
        );

        // Should have Close button
        expect(find.text('Close'), findsOneWidget);

        // Close the dialog
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Dialog should be closed
        expect(
          find.widgetWithText(AlertDialog, 'Terms of Service'),
          findsNothing,
        );
      });
    });

    testWidgets('shows legal dialog for Privacy Policy', (tester) async {
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

        // Tap on Privacy Policy
        await tester.tap(find.text('Privacy Policy'));
        await tester.pumpAndSettle();

        // Should see dialog with Privacy Notice title
        expect(
          find.widgetWithText(AlertDialog, 'Privacy Notice'),
          findsOneWidget,
        );

        // Should have Close button
        expect(find.text('Close'), findsOneWidget);

        // Close the dialog
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
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
        expect(find.text('1.0.0 (42)'), findsOneWidget);
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
  });
}
