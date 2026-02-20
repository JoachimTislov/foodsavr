import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorHandler {
  static String getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'auth_error_user_not_found'.tr();
        case 'wrong-password':
          return 'auth_error_wrong_password'.tr();
        case 'email-already-in-use':
          return 'auth_error_email_already_in_use'.tr();
        case 'invalid-email':
          return 'auth_error_invalid_email'.tr();
        case 'weak-password':
          return 'auth_error_weak_password'.tr();
        case 'operation-not-allowed':
          return 'auth_error_operation_not_allowed'.tr();
        case 'user-disabled':
          return 'auth_error_user_disabled'.tr();
        default:
          return 'auth_error_unknown'.tr();
      }
    }
    return error.toString();
  }
}
