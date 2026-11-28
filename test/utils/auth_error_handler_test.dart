import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodsavr/utils/auth_error_handler.dart';

void main() {
  String identity(String key) => key;

  group('AuthErrorHandler.getProviderErrorMessage', () {
    test('maps popup-timeout to the provider failure message', () {
      expect(
        AuthErrorHandler.getProviderErrorMessage(
          SignInProvider.facebook,
          FirebaseAuthException(code: 'popup-timeout'),
          identity,
        ),
        'auth.error.facebook_failed',
      );
      expect(
        AuthErrorHandler.getProviderErrorMessage(
          SignInProvider.google,
          FirebaseAuthException(code: 'popup-timeout'),
          identity,
        ),
        'auth.error.google_failed',
      );
      expect(
        AuthErrorHandler.getProviderErrorMessage(
          SignInProvider.guest,
          FirebaseAuthException(code: 'popup-timeout'),
          identity,
        ),
        'auth.error.guest_failed',
      );
    });

    test('maps TimeoutException to the provider failure message', () {
      expect(
        AuthErrorHandler.getProviderErrorMessage(
          SignInProvider.facebook,
          TimeoutException('timed out'),
          identity,
        ),
        'auth.error.facebook_failed',
      );
      expect(
        AuthErrorHandler.getProviderErrorMessage(
          SignInProvider.google,
          TimeoutException('timed out'),
          identity,
        ),
        'auth.error.google_failed',
      );
    });

    test('treats explicit user cancellations as silent', () {
      for (final code in [
        'ERROR_ABORTED_BY_USER',
        'popup-closed-by-user',
        'cancelled-popup-request',
      ]) {
        expect(
          AuthErrorHandler.getProviderErrorMessage(
            SignInProvider.facebook,
            FirebaseAuthException(code: code),
            identity,
          ),
          isNull,
          reason: code,
        );
      }
    });
  });
}
