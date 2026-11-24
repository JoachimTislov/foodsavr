import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/widgets/common/adaptive_sheet.dart';

void main() {
  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AdaptiveSheet.show<bool>(
                context,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('body'),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('done'),
                    ),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Compact shows a bottom sheet', (tester) async {
    await open(tester, const Size(390, 844));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    final rect = tester.getRect(find.byType(BottomSheet));
    expect(rect.bottom, 844);
    expect(rect.width, 390);

    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
  });

  testWidgets('Medium shows a 560 dp dialog', (tester) async {
    await open(tester, const Size(768, 900));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    final surface = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(Material),
    );
    expect(tester.getSize(surface.first).width, AdaptiveSheet.dialogWidth);

    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
  });
}
