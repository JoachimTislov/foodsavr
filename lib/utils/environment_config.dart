import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // .env file not found - use defaults
      // This is expected in CI/CD environments
    }
  }

  static String get environment {
    return dotenv.env['ENVIRONMENT'] ?? 'development';
  }

  static String get testUserEmail {
    return dotenv.env['TEST_USER_EMAIL'] ?? 'bob@example.com';
  }

  static String get testUserPassword {
    return dotenv.env['TEST_USER_PASSWORD'] ?? 'password';
  }

  static bool get isProduction {
    return environment == 'production';
  }

  static bool get isDevelopment {
    return !isProduction;
  }
}
