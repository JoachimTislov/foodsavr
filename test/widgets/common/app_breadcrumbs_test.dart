import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/routes/page_trail.dart';
import 'package:foodsavr/utils/app_theme.dart';
import 'package:foodsavr/utils/platform_capabilities.dart';
import 'package:foodsavr/widgets/common/app_breadcrumbs.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_translation_loader.dart';

void main() {
  late TestTranslationLoader translations;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    translations = TestTranslationLoader();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    EasyLocalization.logger.enableBuildModes = [];
    await EasyLocalization.ensureInitialized();
  });

  tearDown(() {
    PlatformCapabilities.testSignalsOverride = null;
  });

  test(
    'resolveBreadcrumbs maps known segments to existing translation keys',
    () {
      final transfer = AppBreadcrumbs.resolveBreadcrumbs('/dashboard/transfer');
      expect(transfer.map((e) => e.path), [
        '/dashboard',
        '/dashboard/transfer',
      ]);
      expect(transfer.map((e) => e.translationKey), [
        'dashboard.title',
        'transfer.title',
      ]);

      final integrations = AppBreadcrumbs.resolveBreadcrumbs(
        '/settings/web-view',
      );
      expect(integrations.map((e) => e.path), [
        '/settings',
        '/settings/web-view',
      ]);
      expect(integrations.map((e) => e.translationKey), [
        'settings.title',
        'settings.integrations.title',
      ]);

      final dashboardPages = AppBreadcrumbs.resolveBreadcrumbs(
        '/dashboard/registry',
      );
      expect(dashboardPages.last.translationKey, 'dashboard.globalProducts');
      expect(
        AppBreadcrumbs.resolveBreadcrumbs(
          '/dashboard/my-products',
        ).last.translationKey,
        'product.all_products',
      );
      expect(
        AppBreadcrumbs.resolveBreadcrumbs(
          '/dashboard/receipts',
        ).last.translationKey,
        'receipt.listTitle',
      );

      final products = AppBreadcrumbs.resolveBreadcrumbs('/products');
      expect(products.single.translationKey, 'product.all_products');

      final custom = AppBreadcrumbs.resolveBreadcrumbs(
        '/dashboard/custom-view',
      );
      expect(custom.last.translationKey, isNull);
      expect(custom.last.fallbackLabel, 'Custom View');
    },
  );

  Widget wrapWithLocalization(Widget child) => EasyLocalization(
    supportedLocales: const [Locale('en')],
    startLocale: const Locale('en'),
    saveLocale: false,
    path: 'assets/translations',
    assetLoader: translations,
    child: child,
  );

  testWidgets(
    'wide viewport shows clickable ancestor breadcrumb with dark link style and hover underline',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      String? navigatedPath;
      await tester.pumpWidget(
        wrapWithLocalization(
          Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: AppBreadcrumbs(
                  pathOverride: '/dashboard/transfer',
                  onNavigate: (path) => navigatedPath = path,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Transfer Inventory'), findsOneWidget);

      final ancestorText = tester.widget<Text>(find.text('Dashboard'));
      expect(ancestorText.style?.color, AppTheme.lightLinkColor);
      expect(ancestorText.style?.decoration, TextDecoration.none);

      // Hover over ancestor link reveals underline and darker hover color
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Dashboard')));
      await tester.pumpAndSettle();

      final hoveredText = tester.widget<Text>(find.text('Dashboard'));
      expect(hoveredText.style?.color, AppTheme.lightLinkHoverColor);
      expect(hoveredText.style?.decoration, TextDecoration.underline);

      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text('Dashboard')),
        isSemantics(label: 'Dashboard', isButton: true, hasTapAction: true),
      );
      semantics.dispose();

      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(navigatedPath, '/dashboard');
    },
  );

  GoRouter shellRouter() => GoRouter(
    initialLocation: '/settings',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            Scaffold(body: AppBreadcrumbs(child: shell)),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const Text('Settings Root'),
                routes: [
                  GoRoute(
                    path: 'web-view',
                    builder: (context, state) =>
                        const Text('Integrations Page'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/legal/terms',
        pageBuilder: (context, state) =>
            const MaterialPage(fullscreenDialog: true, child: SizedBox()),
      ),
    ],
  );

  Future<void> pumpRouter(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(
      wrapWithLocalization(
        Builder(
          builder: (context) => MaterialApp.router(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final navigation in ['go', 'push']) {
    testWidgets('wide breadcrumbs follow $navigation inside the shell', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = shellRouter();
      addTearDown(router.dispose);
      await pumpRouter(tester, router);

      // A root page has a title of its own, so no single-crumb bar.
      expect(find.text('Settings'), findsNothing);

      if (navigation == 'go') {
        router.go('/settings/web-view');
      } else {
        unawaited(router.push<void>('/settings/web-view'));
      }
      await tester.pumpAndSettle();

      expect(find.text('Integrations Page'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Grocery integrations'), findsOneWidget);

      // A root-level modal does not replace the trail underneath.
      unawaited(router.push<void>('/legal/terms'));
      await tester.pumpAndSettle();
      expect(
        AppBreadcrumbs.shellPath(router.routerDelegate.currentConfiguration),
        '/settings/web-view',
      );
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Root'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
      expect(router.state.uri.path, '/settings');
    });
  }

  testWidgets('narrow viewport renders no bar and no second back button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = shellRouter();
    addTearDown(router.dispose);
    await pumpRouter(tester, router);

    router.go('/settings/web-view');
    await tester.pumpAndSettle();

    expect(find.text('Integrations Page'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('the bar consumes the top inset of the content below', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.reset);

    late double childTopInset;
    Widget build(String path) => wrapWithLocalization(
      MaterialApp(
        home: AppBreadcrumbs(
          pathOverride: path,
          child: Builder(
            builder: (context) {
              childTopInset = MediaQuery.paddingOf(context).top;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(build('/settings'));
    await tester.pumpAndSettle();
    expect(childTopInset, 24);

    await tester.pumpWidget(build('/settings/web-view'));
    await tester.pumpAndSettle();
    expect(childTopInset, 0);
  });

  testWidgets('pushed pages appear as crumbs and pop when tapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final trail = PageTrail();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      wrapWithLocalization(
        Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            navigatorKey: navigatorKey,
            navigatorObservers: [trail],
            builder: (context, child) => AppBreadcrumbs(
              pathOverride: '/my-inventory',
              onNavigate: (_) {},
              trail: trail,
              child: child!,
            ),
            home: const Text('Inventory Root'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inventory'), findsNothing);

    final context = navigatorKey.currentContext!;
    unawaited(
      PageTrail.push<void>(
        context,
        label: 'Pantry',
        builder: (_) => const Text('Pantry Page'),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      PageTrail.push<void>(
        context,
        label: 'Milk',
        builder: (_) => const Text('Milk Page'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pantry'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Milk Page'), findsOneWidget);

    await tester.tap(find.text('Pantry'));
    await tester.pumpAndSettle();

    expect(find.text('Pantry Page'), findsOneWidget);
    expect(find.text('Milk Page'), findsNothing);
    expect(trail.routes.last.settings.name, 'Pantry');
  });
}
