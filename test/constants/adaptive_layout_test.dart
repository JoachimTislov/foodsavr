import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/adaptive_layout.dart';
import 'package:foodsavr/constants/material3_config.dart';

void main() {
  test('WindowSize.fromWidth follows the Material 3 breakpoints', () {
    expect(WindowSize.fromWidth(320), WindowSize.compact);
    expect(WindowSize.fromWidth(599.9), WindowSize.compact);
    expect(WindowSize.fromWidth(600), WindowSize.medium);
    expect(WindowSize.fromWidth(839.9), WindowSize.medium);
    expect(WindowSize.fromWidth(840), WindowSize.expanded);
    expect(WindowSize.fromWidth(1920), WindowSize.expanded);
    expect(WindowSize.compact.isCompact, isTrue);
    expect(WindowSize.expanded.isExpanded, isTrue);
  });

  test('gutterFor splits the space beyond the maximum width', () {
    expect(AdaptiveLayout.gutterFor(500, 960), 0);
    expect(AdaptiveLayout.gutterFor(960, 960), 0);
    expect(AdaptiveLayout.gutterFor(1200, 960), 120);
  });

  test('tokens distinguish crisp desktop radii from mobile radii', () {
    final mobile = AdaptiveLayout.tokensFor(WindowSize.compact);
    final tablet = AdaptiveLayout.tokensFor(WindowSize.medium);
    final desktop = AdaptiveLayout.tokensFor(WindowSize.expanded);

    expect(mobile.cardRadius, Material3Config.radiusLarge);
    expect(tablet.cardRadius, Material3Config.radiusMedium);
    expect(desktop.cardRadius, Material3Config.radiusDesktopLarge);
    expect(desktop.cardRadius, lessThan(mobile.cardRadius));
    expect(desktop.cardRadius, inInclusiveRange(8.0, 12.0));

    expect(mobile.controlRadius, Material3Config.radiusMedium);
    expect(desktop.controlRadius, Material3Config.radiusDesktopMedium);
    expect(desktop.controlRadius, inInclusiveRange(8.0, 12.0));

    expect(desktop.pagePadding.left, greaterThan(mobile.pagePadding.left));
    expect(desktop.sectionSpacing, greaterThan(mobile.sectionSpacing));
    expect(
      desktop.cardPadding.left,
      greaterThanOrEqualTo(mobile.cardPadding.left),
    );
    expect(desktop.maxContentWidth, AdaptiveLayout.pageMaxWidth);
  });

  testWidgets('context helpers resolve viewport class and tokens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late bool isDesktop;
    late AdaptiveLayoutTokens tokens;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            isDesktop = AdaptiveLayout.isDesktop(context);
            tokens = AdaptiveLayout.tokensOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(isDesktop, isTrue);
    expect(tokens, same(AdaptiveLayoutTokens.expanded));
  });
}
