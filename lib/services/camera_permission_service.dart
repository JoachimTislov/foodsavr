import 'package:camera/camera.dart' show CameraException;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service_locator.dart';
import 'camera_permission_service_stub.dart'
    if (dart.library.js_interop) 'camera_permission_service_web.dart';
import 'camera_preference_service.dart';

/// Why the camera can or cannot be used.
enum CameraAccessStatus {
  granted,

  /// Nothing is decided yet; asking shows the browser or system prompt.
  prompt,

  /// The user turned camera access off in the app's settings.
  disabledInSettings,

  /// The browser or operating system refused access.
  denied,
  noCamera,

  /// Browsers only offer the camera over HTTPS and on localhost.
  insecureContext,

  /// The camera exists but could not start, usually because it is in use.
  inUse,
  unsupported;

  /// Whether asking again cannot be the next step without telling the user
  /// what is wrong.
  bool get isFailure => this != granted && this != prompt;
}

/// The camera access of the browser or operating system.
abstract interface class CameraAccessPlatform {
  /// Reads the current state without prompting; null when it cannot be read.
  Future<CameraAccessStatus?> query();

  /// Asks for access, prompting the user when needed.
  Future<CameraAccessStatus> request();
}

/// Combines the user's camera setting with the platform's permission, and
/// remembers the last grant or denial across sessions.
@lazySingleton
class CameraPermissionService {
  static const stateKey = 'camera_permission_state';

  final CameraPreferenceService _preference;
  final CameraAccessPlatform _platform;
  late final SharedPreferencesAsync _store = SharedPreferencesAsync();

  CameraPermissionService(this._preference)
    : _platform = createCameraAccessPlatform();

  @visibleForTesting
  CameraPermissionService.withPlatform(this._preference, this._platform);

  /// The registered instance, or a new one in isolated widget tests.
  static CameraPermissionService resolve() =>
      getIt.isRegistered<CameraPermissionService>()
      ? getIt<CameraPermissionService>()
      : CameraPermissionService(CameraPreferenceService());

  /// Whether the user's setting allows the camera. Unreadable storage counts
  /// as the default, enabled.
  Future<bool> isEnabled() async {
    try {
      return await _preference.isEnabled();
    } catch (e) {
      debugPrint('Could not read the camera setting: $e');
      return true;
    }
  }

  /// Turns the app's camera setting back on.
  Future<void> enable() async {
    try {
      await _preference.setEnabled(true);
    } catch (e) {
      debugPrint('Could not save the camera setting: $e');
    }
  }

  /// The current status without prompting the user.
  Future<CameraAccessStatus> check() async {
    if (!await isEnabled()) return CameraAccessStatus.disabledInSettings;
    CameraAccessStatus? current;
    try {
      current = await _platform.query();
    } catch (e) {
      current = classifyError(e);
    }
    if (current != null) {
      await record(current);
      return current;
    }
    return await persistedStatus() ?? CameraAccessStatus.prompt;
  }

  /// Asks for camera access; the user's setting still wins.
  Future<CameraAccessStatus> request() async {
    if (!await isEnabled()) return CameraAccessStatus.disabledInSettings;
    CameraAccessStatus status;
    try {
      status = await _platform.request();
    } catch (e) {
      status = classifyError(e);
    }
    await record(status);
    return status;
  }

  /// What to tell the user where live scanning cannot run: the problem with
  /// the camera when there is one, otherwise that scanning is unsupported.
  /// With [ask], the permission is requested first.
  Future<CameraAccessStatus> scanBlocker({bool ask = false}) async {
    final status = ask ? await request() : await check();
    return status.isFailure ? status : CameraAccessStatus.unsupported;
  }

  /// The grant or denial seen last, or null when neither is known.
  Future<CameraAccessStatus?> persistedStatus() async {
    try {
      return switch (await _store.getString(stateKey)) {
        'granted' => CameraAccessStatus.granted,
        'denied' => CameraAccessStatus.denied,
        _ => null,
      };
    } catch (e) {
      debugPrint('Could not read the camera permission state: $e');
      return null;
    }
  }

  /// Stores a grant or denial. A pending prompt means an earlier decision was
  /// reset; other statuses say nothing about the permission.
  Future<void> record(CameraAccessStatus status) async {
    try {
      switch (status) {
        case CameraAccessStatus.granted || CameraAccessStatus.denied:
          await _store.setString(stateKey, status.name);
        case CameraAccessStatus.prompt:
          await _store.remove(stateKey);
        default:
          break;
      }
    } catch (e) {
      debugPrint('Could not save the camera permission state: $e');
    }
  }

  /// The status behind a camera plugin [error].
  static CameraAccessStatus classifyError(Object error) {
    if (error is MissingPluginException) return CameraAccessStatus.unsupported;
    final code = switch (error) {
      PlatformException(:final code) => code,
      CameraException(:final code) => code,
      _ => '',
    };
    return statusForCameraErrorCode(code);
  }
}

/// Maps browser `DOMException` names and camera plugin error codes. An unknown
/// error means the camera could not start.
CameraAccessStatus statusForCameraErrorCode(String code) => switch (code) {
  'NotAllowedError' ||
  'PermissionDeniedError' ||
  'SecurityError' ||
  'CameraAccessDenied' ||
  'CameraAccessDeniedWithoutPrompt' ||
  'CameraAccessRestricted' ||
  'permissionDenied' ||
  'cameraPermission' => CameraAccessStatus.denied,
  'NotFoundError' ||
  'DevicesNotFoundError' ||
  'OverconstrainedError' ||
  'ConstraintNotSatisfiedError' ||
  'cameraNotFound' ||
  'noCamerasAvailable' => CameraAccessStatus.noCamera,
  'NotSupportedError' ||
  'TypeError' ||
  'cameraNotSupported' => CameraAccessStatus.unsupported,
  _ => CameraAccessStatus.inUse,
};
