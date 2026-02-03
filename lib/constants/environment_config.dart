import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  static Future<void> load() async {
    await dotenv.load();
  }

  static String? get baseApiUrl {
    return dotenv.env['BASE_API_URL'];
  }

  static String? get testUserEmail {
    return dotenv.env['TEST_USER_EMAIL'] ?? '';
  }

  static String? get testUserPassword {
    return dotenv.env['TEST_USER_PASSWORD'] ?? '';
  }
}
