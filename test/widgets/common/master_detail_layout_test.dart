import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foodsavr/constants/adaptive_layout.dart';
import 'package:foodsavr/widgets/common/master_detail_layout.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    EasyLocalization.logger.enableLevels = [];
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(
    WidgetTester tester,
    double width, {
    Widget? detail,
    bool enabled = true,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MasterDetailLayout(
            enabled: enabled,
            master: const SizedBox.expand(
              key: Key('master'),
              child: Center(child: Text('master')),
            ),
            detail: detail,
          ),
        ),
      ),
    );
  }

  testWidgets('compact shows the master only', (tester) async {
    await pump(tester, 400, detail: const Text('detail'));
    expect(find.text('master'), findsOneWidget);
    expect(find.text('detail'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('master'))).width, 400);
  });

  testWidgets('medium shows the master only', (tester) async {
    await pump(tester, 700, detail: const Text('detail'));
    expect(find.text('detail'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('master'))).width, 700);
  });

  testWidgets('expanded shows master and detail side by side', (tester) async {
    await pump(tester, 1300, detail: const Text('detail'));
    expect(find.text('master'), findsOneWidget);
    expect(find.text('detail'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('master'))).width,
      AdaptiveLayout.masterPaneWidth,
    );
    expect(
      tester.getCenter(find.text('detail')).dx,
      greaterThan(AdaptiveLayout.masterPaneWidth),
    );
  });

  testWidgets('expanded without a selection shows the prompt', (tester) async {
    await pump(tester, 1300);
    expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
  });

  testWidgets('disabled layout shows the master only', (tester) async {
    await pump(tester, 1300, detail: const Text('detail'), enabled: false);
    expect(find.text('detail'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('master'))).width, 1300);
  });

  testWidgets('master keeps its state across the breakpoint', (tester) async {
    await pump(tester, 400);
    final before = tester.state(find.byType(MasterDetailLayout));
    tester.view.physicalSize = const Size(1300, 900);
    await tester.pump();
    expect(tester.state(find.byType(MasterDetailLayout)), same(before));
    expect(find.text('master'), findsOneWidget);
  });
}
