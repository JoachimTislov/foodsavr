import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user allows FoodSavr to use the camera on this device.
///
/// This is the app's own preference; the browser or operating system asks for
/// its permission separately.
@lazySingleton
class CameraPreferenceService {
  static const preferenceKey = 'camera_access_enabled';

  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  /// Enabled until the user turns it off.
  Future<bool> isEnabled() async =>
      await _preferences.getBool(preferenceKey) ?? true;

  Future<void> setEnabled(bool enabled) =>
      _preferences.setBool(preferenceKey, enabled);
}
