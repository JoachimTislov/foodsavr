import 'package:flutter/services.dart';

class Config {
  // isDevelopment is default when appFlavor isn't set
  static const bool isDevelopment = appFlavor == null;
  static const String? environment = isDevelopment ? 'development' : appFlavor;

  /// The IP address for local development emulators.
  ///
  /// 💡 For Android emulators, this MUST be '10.0.2.2'.
  /// 💡 For physical Android devices, use your host's local IP (e.g., '192.168.x.x').
  /// ⚠️ IMPORTANT: If you change this, you MUST also update the domain in:
  /// `android/app/src/main/res/xml/network_security_config.xml`
  static const String emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '192.168.0.253',
  );

  static const String testUserEmail = 'bob@example.com';
  static const String testUserPassword = 'password123';
}
