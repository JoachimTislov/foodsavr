import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/test_translation_loader.dart';

final Map<String, TestTranslationLoader> _loaders = {};

/// Prepares real translations and empty in-memory preferences.
Future<void> setUpLocalizedApp() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  EasyLocalization.logger.enableLevels = [];
  EasyLocalization.logger.enableBuildModes = [];
  await EasyLocalization.ensureInitialized();
  for (final language in ['en', 'nb']) {
    _loaders[language] = TestTranslationLoader(language);
  }
}

/// Pumps [home], or the router in [routerConfig], with real translations.
Future<void> pumpLocalized(
  WidgetTester tester,
  Widget? home, {
  RouterConfig<Object>? routerConfig,
  String language = 'en',
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      key: ValueKey(language),
      supportedLocales: [Locale(language)],
      startLocale: Locale(language),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: _loaders[language]!,
      child: Builder(
        builder: (context) => routerConfig == null
            ? MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: home,
              )
            : MaterialApp.router(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                routerConfig: routerConfig,
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
