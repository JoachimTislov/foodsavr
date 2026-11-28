import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/app_theme.dart';
import 'package:foodsavr/widgets/common/app_navigation_rail.dart';

void main() {
  testWidgets(
    'AppNavigationRail exposes click cursor, hover feedback, and selection',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AppNavigationRail(
              selectedIndex: 0,
              extended: true,
              onDestinationSelected: (index) => selected = index,
              items: const [
                AppNavigationRailItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Dashboard',
                ),
                AppNavigationRailItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
      for (final inkWell in inkWells) {
        expect(inkWell.mouseCursor, SystemMouseCursors.click);
      }

      // Hover unselected item and verify tap invokes selection callback
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Settings')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(selected, 1);
    },
  );

  testWidgets('footer items follow the main items and mark the selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AppNavigationRail(
            selectedIndex: 2,
            extended: true,
            onDestinationSelected: (index) => selected = index,
            items: const [
              AppNavigationRailItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Dashboard',
              ),
              AppNavigationRailItem(
                icon: Icons.list_outlined,
                selectedIcon: Icons.list,
                label: 'Lists',
              ),
            ],
            footerItems: const [
              AppNavigationRailItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profile',
              ),
              AppNavigationRailItem(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    expect(selected, 3);
    await tester.tap(find.byTooltip('Profile'));
    expect(selected, 2);
  });
}
