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
            supportedLocales: const [Locale('en', 'US'), Locale('nb', 'NO')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en', 'US'),
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
            supportedLocales: const [Locale('en', 'US'), Locale('nb', 'NO')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en', 'US'),
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

        // Title should now be 'Innstillinger' (Norwegian for Settings)
        expect(find.text('Innstillinger'), findsOneWidget);

        // Sections should be translated
        expect(find.text('KONTO'), findsOneWidget);
        expect(find.text('UTSEENDE'), findsOneWidget);
        expect(find.text('OM'), findsOneWidget);

        // Language text in settings tile should update to Norsk (English is 'Engelsk' in NB)
        expect(find.text('Norsk'), findsOneWidget);
      });
    });
  });
}
