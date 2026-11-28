import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/routes/page_trail.dart';
import 'package:foodsavr/views/main_navigation_view.dart';
import 'package:foodsavr/widgets/common/app_navigation_rail.dart';
import 'package:foodsavr/widgets/common/lettmat_logo.dart';
import 'package:foodsavr/widgets/settings/shorthand_toggles.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();
  });

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/a',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            MainNavigationView(navigationShell: shell),
        branches: [
          for (final (i, name) in ['a', 'b', 'c', 'd', 'e'].indexed)
            StatefulShellBranch(
              observers: [PageTrail.branches[i]],
              routes: [
                GoRoute(
                  path: '/$name',
                  builder: (context, state) => Text('page $name'),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, double width, GoRouter router) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('compact width uses the bottom navigation bar', (tester) async {
    await pump(tester, 400, buildRouter());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(AppNavigationRail), findsNothing);
  });

  testWidgets('medium width uses a collapsed navigation rail', (tester) async {
    await pump(tester, 700, buildRouter());
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.widget<AppNavigationRail>(find.byType(AppNavigationRail)).extended,
      isFalse,
    );
  });

  testWidgets('expanded width keeps a rail beside the content', (tester) async {
    await pump(tester, 1000, buildRouter());
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<AppNavigationRail>(
      find.byType(AppNavigationRail),
    );
    expect(rail.extended, isFalse);
  });

  testWidgets('wide expanded width extends the rail', (tester) async {
    await pump(tester, 1400, buildRouter());
    expect(
      tester.widget<AppNavigationRail>(find.byType(AppNavigationRail)).extended,
      isTrue,
    );
  });

  for (final width in [400.0, 700.0, 1400.0]) {
    testWidgets('selecting a destination switches branch at $width px', (
      tester,
    ) async {
      final router = buildRouter();
      await pump(tester, width, router);
      expect(find.text('page a'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/c');
    });
  }

  testWidgets('branch state survives crossing a breakpoint', (tester) async {
    final router = buildRouter();
    await pump(tester, 400, router);
    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();
    final page = tester.state(find.byType(Navigator).last);

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();

    expect(find.byType(AppNavigationRail), findsOneWidget);
    expect(find.text('page b'), findsOneWidget);
    expect(tester.state(find.byType(Navigator).last), same(page));
  });

  testWidgets('rail destinations are exposed as tabs with selection', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, 1000, buildRouter());

    final tabs = find.semantics.byPredicate(
      (node) => node.getSemanticsData().role == SemanticsRole.tab,
    );
    expect(tabs, findsNWidgets(3));
    expect(tabs.evaluate().first.getSemanticsData().label, 'dashboard.title');
    handle.dispose();
  });

  testWidgets('compact bar has five destinations and no task bar', (
    tester,
  ) async {
    await pump(tester, 400, buildRouter());

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byType(LanguageTogglePill), findsNothing);
    expect(find.byType(ThemeTogglePill), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);
  });

  testWidgets('only the extended rail shows the brand mark', (tester) async {
    await pump(tester, 1400, buildRouter());
    expect(find.byType(LettMatLogo), findsOneWidget);

    tester.view.physicalSize = const Size(900, 900);
    await tester.pumpAndSettle();
    expect(find.byType(LettMatLogo), findsNothing);
  });

  for (final width in [700.0, 1400.0]) {
    testWidgets('rail footer buttons select profile and settings at $width', (
      tester,
    ) async {
      final router = buildRouter();
      await pump(tester, width, router);
      expect(find.byType(NavigationDestination), findsNothing);

      await tester.tap(find.byTooltip('profile.title'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/d');
      expect(find.byIcon(Icons.person), findsOneWidget);

      await tester.tap(find.byTooltip('settings.title'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/e');
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  }

  testWidgets('the wide shell has no task bar controls', (tester) async {
    await pump(tester, 1400, buildRouter());

    expect(find.byType(LanguageTogglePill), findsNothing);
    expect(find.byType(ThemeTogglePill), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);
  });

  testWidgets('re-tapping the current destination pops pushed pages', (
    tester,
  ) async {
    await pump(tester, 400, buildRouter());

    unawaited(
      PageTrail.push<void>(
        tester.element(find.text('page a')),
        label: 'Detail',
        builder: (_) => const Text('detail page'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('detail page'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();

    expect(find.text('detail page'), findsNothing);
    expect(find.text('page a'), findsOneWidget);
  });
}
