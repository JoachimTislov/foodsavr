import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorHandler {
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
        default:
          return 'auth.error.unknown'.tr();
      }
    }
    return error.toString();
  }
}
