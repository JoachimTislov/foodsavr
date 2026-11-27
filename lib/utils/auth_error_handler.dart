import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum SignInProvider { google, facebook, guest }

/// Codes meaning the provider is disabled or not set up for this build or
/// domain, so retrying cannot help.
const _setupErrorCodes = {
  'admin-restricted-operation', // Anonymous sign-in is disabled.
  'operation-not-allowed',
  'unauthorized-domain',
  'invalid-oauth-client-id',
  'invalid-oauth-provider',
  'invalid-api-key',
  'invalid-app-id',
  'invalid-app-credential',
  'invalid-cert-hash',
  'missing-client-identifier',
  'app-not-authorized',
  'auth-domain-config-required',
  'configuration-not-found',
  'operation-not-supported-in-this-environment',
  'google-sdk-unavailable',
  'facebook-sdk-unavailable',
};

const _accountExistsCode = 'account-exists-with-different-credential';

const _cancelledCodes = {
  'ERROR_ABORTED_BY_USER',
  'popup-closed-by-user',
  'cancelled-popup-request',
  'web-context-canceled',
  'web-context-cancelled',
  'user-cancelled',
};

class AuthErrorHandler {
  /// Explains why signing in with [provider] failed, or returns null when the
  /// user cancelled and there is nothing to report.
  static String? getProviderErrorMessage(
    SignInProvider provider,
    Object error,
    String Function(String) tr,
  ) {
    final code = error is FirebaseAuthException ? error.code : null;
    if (_cancelledCodes.contains(code)) return null;
    // Firebase appends the full explanation to the invalid API key code.
    if (_setupErrorCodes.contains(code) ||
        (code?.startsWith('api-key-not-valid') ?? false)) {
      return switch (provider) {
        SignInProvider.google => tr('auth.error.google_unavailable'),
        SignInProvider.facebook => tr('auth.error.facebook_unavailable'),
        SignInProvider.guest => tr('auth.error.guest_unavailable'),
      };
    }
    return switch (code) {
      'popup-blocked' => tr('auth.error.popup_blocked'),
      'web-storage-unsupported' => tr('auth.error.web_storage_unsupported'),
      'network-request-failed' => tr('auth.error.network'),
      _accountExistsCode => tr('auth.error.account_exists'),
      'user-disabled' => tr('auth.error.user_disabled'),
      _ => switch (provider) {
        SignInProvider.google => tr('auth.error.google_failed'),
        SignInProvider.facebook => tr('auth.error.facebook_failed'),
        SignInProvider.guest => tr('auth.error.guest_failed'),
      },
    };
  }

  static String getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'auth.error.user_not_found'.tr();
        case 'wrong-password':
          return 'auth.error.wrong_password'.tr();
        case 'email-already-in-use':
          return 'auth.error.email_already_in_use'.tr();
        case 'invalid-email':
          return 'auth.error.invalid_email'.tr();
        case 'weak-password':
          return 'auth.error.weak_password'.tr();
        case 'operation-not-allowed':
          return 'auth.error.operation_not_allowed'.tr();
        case 'user-disabled':
          return 'auth.error.user_disabled'.tr();
        case 'requires-recent-login':
          return 'auth.error.requires_recent_login'.tr();
        case 'operation-not-allowed-in-current-mode':
          return 'profile.change_email_federated'.tr();
        default:
          return 'auth.error.unknown'.tr();
      }
    }
    return error.toString();
  }
}
