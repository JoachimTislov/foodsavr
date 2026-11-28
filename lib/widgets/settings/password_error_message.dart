import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../utils/auth_error_handler.dart';

/// Explains why adding or resetting a password failed.
String passwordErrorMessage(Object error) {
  if (error is! FirebaseAuthException) {
    return 'common.somethingWentWrong'.tr();
  }
  return error.code == 'credential-already-in-use'
      ? 'auth.error.email_already_in_use'.tr()
      : AuthErrorHandler.getErrorMessage(error);
}
