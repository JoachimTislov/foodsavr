import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';
import 'package:foodsavr/service_locator.dart';
import 'package:foodsavr/utils/theme_notifier.dart';
import 'package:foodsavr/views/main_navigation_view.dart';
import 'package:foodsavr/widgets/common/lettmat_logo.dart';
import 'package:foodsavr/widgets/dashboard/desktop_task_bar.dart';
import 'package:foodsavr/widgets/settings/shorthand_toggles.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_translation_loader.dart';
import '../../support/localized_app.dart';

class _Auth extends Mock implements IAuthService {}

class _User extends Mock implements User {}

class _BothLanguages extends AssetLoader {
  final _loaders = {
    for (final code in ['en', 'nb']) code: TestTranslationLoader(code),
  };

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) =>
      _loaders[locale.languageCode]!.load(path, locale);
}

void main() {
  setUpAll(setUpLocalizedApp);

  late _Auth auth;

  setUp(() async {
    await getIt.reset();
    auth = _Auth();
    when(auth.signOut).thenAnswer((_) async {});
    final preferences = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {ThemeNotifier.kThemeModeKey},
      ),
    );
    getIt
      ..registerSingleton<Logger>(Logger(level: Level.off))
      ..registerSingleton<IAuthService>(auth)
      ..registerSingleton<ThemeNotifier>(ThemeNotifier(preferences));
  });

  tearDown(() => getIt.reset());

  Future<GoRouter> pump(
    WidgetTester tester,
    double width, {
    String language = 'en',
    List<String>? languages,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font (Ahem) is far wider than the real one.
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => MainNavigationView(navigationShell: shell),
          branches: [
            for (final path in [
              '/dashboard',
              '/my-inventory',
              '/shopping-lists',
              '/settings',
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(path: path, builder: (_, _) => Text('page $path')),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    if (languages == null) {
      await pumpLocalized(
        tester,
        null,
        routerConfig: router,
        language: language,
      );
    } else {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: [for (final code in languages) Locale(code)],
          startLocale: Locale(language),
          saveLocale: false,
          path: 'assets/translations',
          assetLoader: _BothLanguages(),
          child: Builder(
            builder: (context) => MaterialApp.router(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
    return router;
  }

  for (final language in ['en', 'nb']) {
    for (final width in [600.0, 840.0, 1400.0]) {
      testWidgets(
        'shows language, theme and logout at $width px in $language',
        (tester) async {
          await pump(tester, width, language: language);

          expect(tester.takeException(), isNull);
          expect(find.byType(LanguageTogglePill), findsOneWidget);
          expect(find.byType(ThemeTogglePill), findsOneWidget);
          expect(
            find.text(language == 'en' ? 'Sign Out' : 'Logg ut'),
            findsOneWidget,
          );
          // It runs along the top, above the page.
          expect(
            tester.getBottomLeft(find.byType(DesktopTaskBar)).dy,
            lessThan(tester.getTopLeft(find.text('page /dashboard')).dy + 1),
          );
        },
      );
    }
  }

  testWidgets('compact windows have no task bar or logout button', (
    tester,
  ) async {
    await pump(tester, 390);

    expect(find.byType(DesktopTaskBar), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.byType(LanguageTogglePill), findsNothing);
    expect(find.byType(ThemeTogglePill), findsNothing);
  });

  testWidgets('only the extended rail shows the brand mark', (tester) async {
    await pump(tester, 1400);
    expect(find.byType(LettMatLogo), findsOneWidget);
    expect(find.text('LettMat'), findsOneWidget);

    tester.view.physicalSize = const Size(900, 900);
    await tester.pumpAndSettle();
    expect(find.byType(LettMatLogo), findsNothing);
  });

  testWidgets('Settings keeps logout but not the toggles it already has', (
    tester,
  ) async {
    final router = await pump(tester, 1400);

    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.byType(LanguageTogglePill), findsNothing);
    expect(find.byType(ThemeTogglePill), findsNothing);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets('the language pill retranslates the shell', (tester) async {
    await pump(tester, 1400, languages: ['en', 'nb']);

    await tester.tap(find.text('NO'));
    await tester.pumpAndSettle();

    expect(find.text('Logg ut'), findsOneWidget);
    expect(find.text('Mitt lager'), findsOneWidget);
    expect(find.text('Innstillinger'), findsOneWidget);
  });

  testWidgets('the theme pill changes the theme', (tester) async {
    await pump(tester, 1000);

    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pumpAndSettle();

    expect(getIt<ThemeNotifier>().themeMode, ThemeMode.dark);
  });

  testWidgets('logout signs out in one click', (tester) async {
    await pump(tester, 1000);

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    verify(auth.signOut).called(1);
  });

  testWidgets('a failed logout is reported', (tester) async {
    when(auth.signOut).thenAnswer((_) async => throw StateError('offline'));
    await pump(tester, 1000);

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to sign out. Please try again.'), findsOneWidget);
  });

  testWidgets('a guest confirms before the account is deleted', (tester) async {
    final guest = _User();
    when(() => guest.isAnonymous).thenReturn(true);
    when(() => auth.currentUser).thenReturn(guest);
    await pump(tester, 1000);

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of the guest account?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(auth.signOut);

    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();
    verify(auth.signOut).called(1);
  });

  testWidgets('controls without a registered dependency are left out', (
    tester,
  ) async {
    await getIt.reset();
    await pump(tester, 1000);

    expect(tester.takeException(), isNull);
    expect(find.byType(LanguageTogglePill), findsOneWidget);
    expect(find.byType(ThemeTogglePill), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);
  });
}
