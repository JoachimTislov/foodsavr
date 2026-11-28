import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/services/camera_permission_service.dart';
import 'package:foodsavr/services/camera_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_camera_access.dart';

void main() {
  late FakeCameraAccess platform;
  late CameraPreferenceService preference;

  CameraPermissionService service() =>
      CameraPermissionService.withPlatform(preference, platform);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    platform = FakeCameraAccess();
    preference = CameraPreferenceService();
  });

  test('the app setting wins over the platform, without asking it', () async {
    await preference.setEnabled(false);

    expect(await service().check(), CameraAccessStatus.disabledInSettings);
    expect(await service().request(), CameraAccessStatus.disabledInSettings);
    expect((platform.queries, platform.requests), (0, 0));
  });

  test('enable turns the app setting back on', () async {
    await preference.setEnabled(false);

    await service().enable();

    expect(await preference.isEnabled(), isTrue);
    expect(await service().request(), CameraAccessStatus.granted);
  });

  for (final status in [
    CameraAccessStatus.granted,
    CameraAccessStatus.denied,
  ]) {
    test('${status.name} persists across sessions', () async {
      platform.answer = status;
      expect(await service().request(), status);

      // A new session on a platform that cannot read the permission.
      platform.current = null;
      expect(await service().persistedStatus(), status);
      expect(await service().check(), status);
      expect(
        await SharedPreferencesAsync().getString('camera_permission_state'),
        status.name,
      );
    });
  }

  test('a retry replaces a stored denial', () async {
    platform.answer = CameraAccessStatus.denied;
    await service().request();
    platform.answer = CameraAccessStatus.granted;

    expect(await service().request(), CameraAccessStatus.granted);
    expect(await service().persistedStatus(), CameraAccessStatus.granted);
  });

  test('a reset browser permission clears the stored decision', () async {
    await service().request();
    platform.current = CameraAccessStatus.prompt;

    expect(await service().check(), CameraAccessStatus.prompt);
    expect(await service().persistedStatus(), isNull);
  });

  test('nothing known means the user can still be asked', () async {
    expect(await service().check(), CameraAccessStatus.prompt);
  });

  for (final status in [
    CameraAccessStatus.noCamera,
    CameraAccessStatus.inUse,
    CameraAccessStatus.insecureContext,
    CameraAccessStatus.unsupported,
  ]) {
    test('${status.name} is reported without replacing the grant', () async {
      await service().request();
      platform.answer = status;

      expect(await service().request(), status);
      expect(await service().persistedStatus(), CameraAccessStatus.granted);
    });
  }

  test('scanBlocker names the camera problem, else unsupported', () async {
    platform.current = CameraAccessStatus.insecureContext;
    expect(await service().scanBlocker(), CameraAccessStatus.insecureContext);

    platform.current = CameraAccessStatus.granted;
    expect(await service().scanBlocker(), CameraAccessStatus.unsupported);
    expect(platform.requests, 0);

    platform.answer = CameraAccessStatus.denied;
    expect(await service().scanBlocker(ask: true), CameraAccessStatus.denied);
    expect(platform.requests, 1);
  });

  test('platform errors are classified', () async {
    platform.error = CameraException('CameraAccessDenied', null);

    expect(await service().request(), CameraAccessStatus.denied);
    expect(await service().check(), CameraAccessStatus.denied);
  });

  test('browser and plugin error codes map to statuses', () {
    const expected = {
      'NotAllowedError': CameraAccessStatus.denied,
      'SecurityError': CameraAccessStatus.denied,
      'CameraAccessDeniedWithoutPrompt': CameraAccessStatus.denied,
      'NotFoundError': CameraAccessStatus.noCamera,
      'OverconstrainedError': CameraAccessStatus.noCamera,
      'ConstraintNotSatisfiedError': CameraAccessStatus.noCamera,
      'NotReadableError': CameraAccessStatus.inUse,
      'AbortError': CameraAccessStatus.inUse,
      'NotSupportedError': CameraAccessStatus.unsupported,
      'something else': CameraAccessStatus.inUse,
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      expect(statusForCameraErrorCode(key), value, reason: key);
    }
    expect(
      CameraPermissionService.classifyError(MissingPluginException()),
      CameraAccessStatus.unsupported,
    );
    expect(
      CameraPermissionService.classifyError(
        PlatformException(code: 'cameraNotFound'),
      ),
      CameraAccessStatus.noCamera,
    );
  });
}
