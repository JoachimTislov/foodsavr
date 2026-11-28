import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/camera_preference_service.dart';
import 'package:foodsavr/widgets/settings/camera_access_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpSettingsWidgetTest();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  bool switchValue(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  testWidgets('is on by default and persists turning it off', (tester) async {
    await pumpSettingsWidget(tester, CameraAccessTile());

    expect(switchValue(tester), isTrue);
    expect(find.textContaining('On. Your browser'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(switchValue(tester), isFalse);
    expect(find.textContaining('Off. Turn on'), findsOneWidget);
    expect(await CameraPreferenceService().isEnabled(), isFalse);
    expect(
      await SharedPreferencesAsync().getBool('camera_access_enabled'),
      isFalse,
    );
  });

  testWidgets('shows a stored preference', (tester) async {
    await CameraPreferenceService().setEnabled(false);

    await pumpSettingsWidget(tester, CameraAccessTile());

    expect(switchValue(tester), isFalse);
  });
}
