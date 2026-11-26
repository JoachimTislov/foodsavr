import 'package:easy_localization/easy_localization.dart';
import 'package:logger/logger.dart';

import '../service_locator.dart';
import '../validation/validation_error.dart';

/// Localized, non-technical text for [error], logging the technical details.
///
/// A [ValidationException] names the failed rule; any other error shows
/// [fallback], an already translated message.
String userErrorMessage(Object error, String fallback, [StackTrace? stack]) {
  if (getIt.isRegistered<Logger>()) {
    getIt<Logger>().w(fallback, error: error, stackTrace: stack);
  }
  if (error is ValidationException) {
    return validationMessage(error.error.code) ?? fallback;
  }
  return fallback;
}

/// Localized text for a validation [code], or null when it has none.
String? validationMessage(ValidationCode? code) => switch (code) {
  ValidationCode.productNameEmpty => 'validation.productNameEmpty'.tr(),
  ValidationCode.nonExpiringQuantityNegative =>
    'validation.nonExpiringQuantityNegative'.tr(),
  ValidationCode.expiryQuantityNotPositive =>
    'validation.expiryQuantityNotPositive'.tr(),
  ValidationCode.collectionNameEmpty => 'validation.collectionNameEmpty'.tr(),
  null => null,
};
