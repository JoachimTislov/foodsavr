import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/theme_notifier.dart';
import 'package:foodsavr/widgets/settings/shorthand_toggles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/test_translation_loader.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestTranslationLoader translations;

  setUp(() async {
    await setUpSettingsWidgetTest();
    translations = TestTranslationLoader();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('the language pill switches between Norwegian and English', (
    tester,
  ) async {
    late BuildContext app;
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('nb')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: translations,
        child: Builder(
          builder: (context) {
            app = context;
            return MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const Scaffold(body: Center(child: LanguageTogglePill())),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('NO'));
    await tester.pumpAndSettle();
    expect(app.locale, const Locale('nb'));

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(app.locale, const Locale('en'));
  });

  testWidgets('the theme pill sets light, system and dark', (tester) async {
    final preferences = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {ThemeNotifier.kThemeModeKey},
      ),
    );
    final notifier = ThemeNotifier(preferences);
    await pumpSettingsWidget(
      tester,
      Center(child: ThemeTogglePill(notifier: notifier)),
    );

    for (final (icon, mode) in [
      (Icons.dark_mode, ThemeMode.dark),
      (Icons.light_mode, ThemeMode.light),
      (Icons.brightness_auto, ThemeMode.system),
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(notifier.themeMode, mode);
    }
    final target = tester.getSize(
      find.ancestor(
        of: find.byIcon(Icons.dark_mode),
        matching: find.byType(InkWell),
      ),
    );
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
  });
}
