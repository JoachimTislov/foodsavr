import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/material3_config.dart';
import 'package:foodsavr/utils/app_theme.dart';
import 'package:foodsavr/widgets/common/navigation_card.dart';

void main() {
  testWidgets(
    'NavigationCard exposes click cursor, desktop radii, hover border, and focus ring',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: NavigationCard(
              title: 'Transfer',
              description: 'Move items between inventories',
              icon: Icons.swap_horiz,
              color: Colors.teal.shade100,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.mouseCursor, SystemMouseCursors.click);

      final initialCard = tester.widget<Card>(find.byType(Card));
      final initialShape = initialCard.shape! as RoundedRectangleBorder;
      expect(
        (initialShape.borderRadius as BorderRadius).topLeft.x,
        Material3Config.radiusDesktopLarge,
      );

      // Hover elevates card and highlights border
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(NavigationCard)));
      await tester.pumpAndSettle();

      final hoveredCard = tester.widget<Card>(find.byType(Card));
      expect(hoveredCard.elevation, Material3Config.elevationLevel2);
      final hoveredShape = hoveredCard.shape! as RoundedRectangleBorder;
      expect(hoveredShape.side.width, 1.5);

      // Keyboard Tab focus applies high-contrast focus ring
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final focusedCard = tester.widget<Card>(find.byType(Card));
      final focusedShape = focusedCard.shape! as RoundedRectangleBorder;
      expect(focusedShape.side.width, Material3Config.focusRingWidth);
      expect(focusedShape.side.color, AppTheme.lightLinkColor);

      await tester.tap(find.byType(NavigationCard));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    },
  );
}
