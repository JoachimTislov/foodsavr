import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/controllers/app_zoom_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts at default scale 1.0 and steps cleanly within bounds', () async {
    final controller = AppZoomController();
    addTearDown(controller.dispose);

    expect(controller.scale, 1.0);
    expect(controller.zoomPercent, 100);
    expect(controller.isDefault, isTrue);

    await controller.zoomIn();
    expect(controller.scale, 1.1);
    expect(controller.zoomPercent, 110);
    expect(controller.isDefault, isFalse);

    await controller.zoomOut();
    expect(controller.scale, 1.0);
    expect(controller.isDefault, isTrue);

    await controller.zoomOut();
    expect(controller.scale, 0.9);
    expect(controller.zoomPercent, 90);
  });

  test('clamps zoom to [minScale, maxScale] and resets cleanly', () async {
    final controller = AppZoomController();
    addTearDown(controller.dispose);

    await controller.setScale(5.0);
    expect(controller.scale, AppZoomController.maxScale);

    await controller.setScale(0.1);
    expect(controller.scale, AppZoomController.minScale);

    await controller.reset();
    expect(controller.scale, AppZoomController.defaultScale);
    expect(controller.isDefault, isTrue);
  });

  test('persists scale to SharedPreferences and restores on launch', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = AppZoomController(preferences: prefs);
    addTearDown(first.dispose);

    await first.setScale(1.3);
    expect(prefs.getDouble(AppZoomController.kZoomScaleKey), 1.3);

    final second = AppZoomController(preferences: prefs);
    addTearDown(second.dispose);
    var notified = false;
    second.addListener(() => notified = true);

    await second.restore();
    expect(second.scale, 1.3);
    expect(notified, isTrue);
  });

  test('restore clamps out-of-range persisted values safely', () async {
    SharedPreferences.setMockInitialValues({
      AppZoomController.kZoomScaleKey: 9.9,
    });
    final controller = AppZoomController();
    addTearDown(controller.dispose);

    await controller.restore();
    expect(controller.scale, AppZoomController.maxScale);
  });
}
