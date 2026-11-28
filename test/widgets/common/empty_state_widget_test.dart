import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/app_theme.dart';
import 'package:foodsavr/utils/platform_capabilities.dart';
import 'package:foodsavr/widgets/common/empty_state_widget.dart';

void main() {
  tearDown(() {
    PlatformCapabilities.testSignalsOverride = null;
  });

  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets(
      'centers empty state text and action buttons directly underneath at $width px',
      (tester) async {
        PlatformCapabilities.testSignalsOverride = PlatformCapabilitySignals(
          userAgentMobile: width < 600,
          hasCoarsePointer: width < 840,
          hasFinePointer: width >= 840,
          maxTouchPoints: width < 840 ? 5 : 0,
          isWeb: true,
        );

        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: EmptyStateWidget(
                icon: Icons.inventory_2_outlined,
                title: 'No products found',
                subtitle: 'Add your first product to get started',
                actions: [
                  FilledButton(
                    onPressed: () {},
                    child: const Text('Add Product'),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Scan Receipt'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleRect = tester.getRect(find.text('No products found'));
        final subtitleRect = tester.getRect(
          find.text('Add your first product to get started'),
        );
        final primaryRect = tester.getRect(find.text('Add Product'));
        final secondaryRect = tester.getRect(find.text('Scan Receipt'));

        // Title and subtitle are horizontally centered within the viewport.
        expect(titleRect.center.dx, closeTo(width / 2, 1.5));
        expect(subtitleRect.center.dx, closeTo(width / 2, 1.5));

        // Action row sits below the subtitle and its combined span is centered.
        expect(primaryRect.top, greaterThan(subtitleRect.bottom));
        expect(secondaryRect.top, greaterThan(subtitleRect.bottom));

        final actionsLeft = primaryRect.left < secondaryRect.left
            ? primaryRect.left
            : secondaryRect.left;
        final actionsRight = primaryRect.right > secondaryRect.right
            ? primaryRect.right
            : secondaryRect.right;
        final actionsCenterX = (actionsLeft + actionsRight) / 2;
        expect(actionsCenterX, closeTo(width / 2, 4.0));
      },
    );
  }
}
