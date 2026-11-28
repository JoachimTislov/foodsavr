import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/constants/material3_config.dart';
import 'package:foodsavr/controllers/app_zoom_controller.dart';
import 'package:foodsavr/utils/app_theme.dart';
import 'package:foodsavr/widgets/common/app_zoom_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Ctrl + =, -, and 0 zoom in, zoom out, and reset', (
    tester,
  ) async {
    final controller = AppZoomController();
    addTearDown(controller.dispose);

    double? observedScale;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) =>
            AppZoomWrapper(controller: controller, child: child!),
        home: Builder(
          builder: (context) {
            observedScale = MediaQuery.textScalerOf(context).scale(1.0);
            return const Scaffold(body: Text('Zoom target'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(observedScale, closeTo(1.0, 0.001));
    expect(find.text('110%'), findsNothing);

    // Ctrl + '=' zooms in
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(controller.scale, 1.1);
    expect(observedScale, closeTo(1.1, 0.001));
    expect(find.text('110%'), findsOneWidget);

    // Ctrl + '-' zooms out back to 100%
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(controller.scale, 1.0);
    expect(find.text('110%'), findsNothing);

    // Zoom in twice then Ctrl + 0 resets
    await controller.setScale(1.3);
    await tester.pumpAndSettle();
    expect(find.text('130%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(controller.scale, 1.0);
    expect(observedScale, closeTo(1.0, 0.001));
  });

  testWidgets('tapping zoom indicator pill resets scale to 100%', (
    tester,
  ) async {
    final controller = AppZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) =>
            AppZoomWrapper(controller: controller, child: child!),
        home: const Scaffold(body: Text('Content')),
      ),
    );
    await tester.pumpAndSettle();
    await controller.setScale(1.2);
    await tester.pumpAndSettle();

    expect(find.text('120%'), findsOneWidget);
    await tester.tap(find.text('120%'));
    await tester.pumpAndSettle();

    expect(controller.scale, 1.0);
    expect(find.text('120%'), findsNothing);
  });

  testWidgets('Ctrl + mouse wheel zooms in and out smoothly', (tester) async {
    final controller = AppZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) =>
            AppZoomWrapper(controller: controller, child: child!),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    tester.binding.handlePointerEvent(
      const PointerScrollEvent(
        position: Offset(200, 200),
        scrollDelta: Offset(0, -120),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.scale, 1.1);

    tester.binding.handlePointerEvent(
      const PointerScrollEvent(
        position: Offset(200, 200),
        scrollDelta: Offset(0, 120),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(controller.scale, 1.0);
  });

  testWidgets(
    'two-finger pinch zooms while single-finger scrolling remains smooth',
    (tester) async {
      final controller = AppZoomController();
      addTearDown(controller.dispose);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) =>
              AppZoomWrapper(controller: controller, child: child!),
          home: Scaffold(
            body: ListView.builder(
              controller: scrollController,
              itemCount: 40,
              itemBuilder: (context, index) =>
                  SizedBox(height: 60, child: Text('Row $index')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Single-finger drag scrolls the ListView without changing zoom
      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(scrollController.offset, greaterThan(100));
      expect(controller.scale, 1.0);

      // Two-finger pinch out zooms in
      final center = tester.getCenter(find.byType(ListView));
      final g1 = await tester.startGesture(center - const Offset(40, 0));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      await g1.moveBy(const Offset(-30, 0));
      await g2.moveBy(const Offset(30, 0));
      await tester.pump();
      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();

      expect(controller.scale, greaterThan(1.0));
    },
  );

  testWidgets('adapts card border radius on desktop viewport width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late double resolvedCardRadius;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => AppZoomWrapper(child: child!),
        home: Builder(
          builder: (context) {
            final shape =
                Theme.of(context).cardTheme.shape! as RoundedRectangleBorder;
            resolvedCardRadius = (shape.borderRadius as BorderRadius).topLeft.x;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(resolvedCardRadius, Material3Config.radiusDesktopLarge);
  });

  testWidgets('the zoom indicator hides itself and keeps the zoom', (
    tester,
  ) async {
    final controller = AppZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) =>
            AppZoomWrapper(controller: controller, child: child!),
        home: const Scaffold(body: Text('Content')),
      ),
    );
    await controller.zoomIn();
    await tester.pumpAndSettle();
    expect(find.text('110%'), findsOneWidget);

    await tester.pump(AppZoomWrapper.indicatorDuration);

    expect(find.text('110%'), findsNothing);
    expect(controller.scale, 1.1);
  });

  testWidgets('zoom multiplies the platform text scale without capping it', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = AppZoomController();
    addTearDown(controller.dispose);

    late double observed;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppZoomWrapper(controller: controller, child: child!),
        home: Builder(
          builder: (context) {
            observed = MediaQuery.textScalerOf(context).scale(10);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(observed, 20);

    await controller.setScale(1.5);
    await tester.pumpAndSettle();
    expect(observed, 30);
  });

  testWidgets('first zoom keeps the state of the app below', (tester) async {
    final controller = AppZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppZoomWrapper(controller: controller, child: child!),
        home: const Scaffold(body: TextField()),
      ),
    );
    final routerState = tester.state(find.byType(Navigator));
    final fieldState = tester.state(find.byType(TextField));

    await controller.zoomIn();
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(Navigator)), same(routerState));
    expect(tester.state(find.byType(TextField)), same(fieldState));
  });

  testWidgets('Ctrl + wheel over a list zooms without scrolling it', (
    tester,
  ) async {
    final controller = AppZoomController();
    addTearDown(controller.dispose);
    final scrollController = ScrollController(initialScrollOffset: 300);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppZoomWrapper(controller: controller, child: child!),
        home: Scaffold(
          body: ListView(
            controller: scrollController,
            children: const [SizedBox(height: 2000)],
          ),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    tester.binding.handlePointerEvent(
      const PointerScrollEvent(
        position: Offset(200, 200),
        scrollDelta: Offset(0, -120),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    expect(controller.scale, 1.1);
    expect(scrollController.offset, 300);
  });

  testWidgets('a large web scale signal moves one step at most', (
    tester,
  ) async {
    final controller = AppZoomController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            AppZoomWrapper(controller: controller, child: child!),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );

    tester.binding.handlePointerEvent(
      const PointerScaleEvent(position: Offset(200, 200), scale: 1.8),
    );
    await tester.pumpAndSettle();
    expect(controller.scale, 1.1);

    tester.binding.handlePointerEvent(
      const PointerScaleEvent(position: Offset(200, 200), scale: 1.004),
    );
    await tester.pumpAndSettle();
    expect(controller.scale, closeTo(1.104, 0.001));
  });

  testWidgets('resizing across breakpoints keeps themed buttons stable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => AppZoomWrapper(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              TextButton(onPressed: () {}, child: const Text('Link')),
              FilledButton(onPressed: () {}, child: const Text('Filled')),
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              const Chip(label: Text('Chip')),
              const TextField(),
            ],
          ),
        ),
      ),
    );

    for (final width in [1280.0, 700.0, 400.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 800);
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
