import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  static const String _flavor = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'development',
  );

  static Future<void> load() async {
    await dotenv.load(fileName: '.env.$_flavor');
  }

  static String? get baseApiUrl {
    return dotenv.env['BASE_API_URL'];
  }

  static String? get firebaseApiKey {
    return dotenv.env['FIREBASE_API_KEY'];
  }

  static String? get geminiApiKey {
    return dotenv.env['GEMINI_API_KEY'];
  }

  static String? get testUserEmail {
    return dotenv.env['TEST_USER_EMAIL'] ?? '';
  }

  static String? get testUserPassword {
    return dotenv.env['TEST_USER_PASSWORD'] ?? '';
  }
}
