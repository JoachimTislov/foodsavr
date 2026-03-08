import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/config.dart';

void main() {
  group('Config', () {
    test('isDevelopment is true when appFlavor is null', () {
      // In a test environment, appFlavor should be null by default
      expect(Config.isDevelopment, isTrue);
    });

    test('environment is "development" when isDevelopment is true', () {
      expect(Config.environment, equals('development'));
    });

    test('emulatorHost returns correct value for web platform', () {
      // This test verifies the emulatorHost constant is accessible
      expect(Config.emulatorHost, isNotNull);
      expect(Config.emulatorHost, isA<String>());

      // In web context, it should be 'localhost'
      // In non-web, it should be the IP address
      if (kIsWeb) {
        expect(Config.emulatorHost, equals('localhost'));
      } else {
        // Default value when EMULATOR_HOST is not set
        expect(Config.emulatorHost, equals('192.168.0.253'));
      }
    });

    test('testUserEmail is defined and has correct format', () {
      expect(Config.testUserEmail, equals('bob@example.com'));
      expect(Config.testUserEmail, contains('@'));
      expect(Config.testUserEmail, isNotEmpty);
    });

    test('testUserPassword is defined and non-empty', () {
      expect(Config.testUserPassword, equals('password123'));
      expect(Config.testUserPassword, isNotEmpty);
      expect(Config.testUserPassword.length, greaterThanOrEqualTo(8));
    });

    test('emulatorHost constant is a valid IP or hostname', () {
      final host = Config.emulatorHost;

      // Should be either 'localhost' or an IP address format
      final isLocalhost = host == 'localhost' || host == '127.0.0.1';
      final isIpAddress = RegExp(
        r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$',
      ).hasMatch(host);

      expect(isLocalhost || isIpAddress, isTrue);
    });

    group('Edge cases', () {
      test('environment is never null', () {
        expect(Config.environment, isNotNull);
      });

      test('emulatorHost is never empty', () {
        expect(Config.emulatorHost, isNotEmpty);
      });

      test('test credentials are valid for Firebase auth format', () {
        // Email should be a valid format
        expect(
          RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
              .hasMatch(Config.testUserEmail),
          isTrue,
        );

        // Password should meet minimum requirements
        expect(Config.testUserPassword.length, greaterThanOrEqualTo(6));
      });
    });

    group('Platform-specific behavior', () {
      test('emulatorHost uses correct default for current platform', () {
        if (kIsWeb) {
          expect(
            Config.emulatorHost,
            equals('localhost'),
            reason: 'Web should use localhost',
          );
        } else {
          // Non-web (mobile/desktop) should use IP address
          expect(
            Config.emulatorHost,
            isNot(equals('localhost')),
            reason: 'Non-web should use IP address',
          );
        }
      });
    });
  });
}