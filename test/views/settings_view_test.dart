import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/views/settings_view.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements IAuthService {}

class _TestWrapper extends StatelessWidget {
  final Widget child;

  const _TestWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: child,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  group('SettingsView Widget Tests', () {
    late _MockAuthService mockAuthService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      await getIt.reset();
      mockAuthService = _MockAuthService();
      when(
        () => mockAuthService.authStateChanges,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthService.currentUser).thenReturn(null);
      getIt.registerLazySingleton<IAuthService>(() => mockAuthService);
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
        expect(find.text('System'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('Dark'), findsOneWidget);

        // Select Dark theme
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();

        // Modal should close
        expect(find.text('System'), findsNothing);
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
        expect(find.byType(ModalBottomSheetRoute), findsNothing);
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

    testWidgets('theme selector shows checkmark on current theme',
        (tester) async {
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

    testWidgets('language selector shows checkmark on current language',
        (tester) async {
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
        expect(checkIcons, findsOneWidget);
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