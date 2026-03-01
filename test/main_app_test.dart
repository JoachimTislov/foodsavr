import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/main.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/services/theme_notifier.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  EasyLocalization.logger.enableBuildModes = [];
  EasyLocalization.logger.enableLevels = [];

  group('MyApp', () {
    late ThemeNotifier themeNotifier;
    late GoRouter router;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
      await getIt.reset();
      final prefs = await SharedPreferences.getInstance();
      themeNotifier = ThemeNotifier(prefs);
      getIt.registerSingleton<ThemeNotifier>(themeNotifier);
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      );
    });

    testWidgets('updates MaterialApp themeMode when ThemeNotifier changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MyApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.system,
      );

      await themeNotifier.setTheme(ThemeMode.dark);
      await tester.pump();

      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    });
  });
}
