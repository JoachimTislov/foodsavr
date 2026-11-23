import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/widgets/common/content_constraint.dart';

void main() {
  const widths = [400.0, 700.0, 1400.0];

  for (final width in widths) {
    testWidgets('ContentConstraint caps the width at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: SingleChildScrollView(
            child: ContentConstraint(
              maxWidth: 600,
              child: SizedBox(key: Key('content'), height: 10, width: 5000),
            ),
          ),
        ),
      );

      final box = tester.getSize(find.byKey(const Key('content')));
      expect(box.width, width < 600 ? width : 600);
    });

    testWidgets('SliverContentConstraint centers slivers at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomScrollView(
            slivers: [
              SliverContentConstraint(
                maxWidth: 600,
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(key: const Key('item'), height: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(const Key('item')));
      final expected = width < 600 ? width : 600.0;
      expect(rect.width, expected);
      expect(rect.left, (width - expected) / 2);
    });
  }
}
