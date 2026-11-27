import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/app_theme.dart';
import 'package:foodsavr/views/splash_view.dart';
import 'package:foodsavr/widgets/common/lettmat_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_translation_loader.dart';

void main() {
  final loader = TestTranslationLoader();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableBuildModes = [];
    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();
  });

  Widget buildSplash(ThemeData theme) {
    return EasyLocalization(
      supportedLocales: const [Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      assetLoader: loader,
      child: Builder(
        builder: (context) => MaterialApp(
          theme: theme,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SplashView(),
        ),
      ),
    );
  }

  testWidgets('renders light themed splash matching pre-boot loader surface', (
    tester,
  ) async {
    await tester.pumpWidget(buildSplash(AppTheme.lightTheme));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFFf6f8f8));
    expect(find.byType(LettMatLogo), findsOneWidget);
    expect(find.text('LettMat'), findsOneWidget);
    expect(find.text('Less waste, easier meals.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Preparing your dashboard…'), findsOneWidget);
  });

  testWidgets('renders dark themed splash matching pre-boot loader surface', (
    tester,
  ) async {
    await tester.pumpWidget(buildSplash(AppTheme.darkTheme));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF101f22));
    expect(find.byType(LettMatLogo), findsOneWidget);
    expect(find.text('LettMat'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
