import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorHandler {
  static String getErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found for that email.'.tr();
        case 'wrong-password':
          return 'Wrong password provided for that user.'.tr();
        case 'email-already-in-use':
          return 'The account already exists for that email.'.tr();
        case 'invalid-email':
          return 'The email address is not valid.'.tr();
        case 'weak-password':
          return 'The password provided is too weak.'.tr();
        case 'operation-not-allowed':
          return 'Operation not allowed.'.tr();
        case 'user-disabled':
          return 'The user account has been disabled.'.tr();
        default:
          return 'An undefined Error happened.'.tr();
      }
    }
    return error.toString();
  }
}
