import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Config {
  static const String environment = appFlavor ?? 'development';

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => appFlavor == 'production';
  static bool get useEmulators => isDevelopment;

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
