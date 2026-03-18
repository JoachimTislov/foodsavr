import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:foodsavr/injection.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Config {
  // isDevelopment is default when appFlavor isn't set
  static const bool isDevelopment = appFlavor == null;
  static const String? environment = isDevelopment ? 'development' : appFlavor;

  static bool get isProduction => appFlavor == 'production';
  bool get useEmulators => !Config.isProduction && _userPrefersEmulators;

  final bool _userPrefersEmulators =
      getIt<SharedPreferences>().getBool(useEmulatorsKey) ??
      Config.isDevelopment;

  /// Key used in SharedPreferences to store the environment preference.
  static const String useEmulatorsKey = 'use_local_emulators';

  /// The IP address for local development emulators.
  ///
  /// 💡 For Android emulators, this MUST be '10.0.2.2'.
  /// 💡 For physical Android devices, use your host's local IP (e.g., '192.168.x.x').
  /// 💡 For Web, 'localhost' or '127.0.0.1' is generally used.
  /// ⚠️ IMPORTANT: If you change this, you MUST also update the domain in:
  /// `android/app/src/main/res/xml/network_security_config.xml`
  static const String emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: kIsWeb ? 'localhost' : '192.168.0.253',
  );

  static const String testUserEmail = 'bob@example.com';
  static const String testUserPassword = 'password123';
}
