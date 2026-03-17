import 'package:easy_localization/easy_localization.dart';

extension LocalizationUtils on String {
  /// Translates the string with [namedArgs] only if [when] is true.
  /// If [when] is false, returns an empty string.
  /// Useful for conditionally showing information like expiry dates.
  ///
  /// Example:
  /// ```dart
  /// 'product.barcodeAssumedExpiry'.trWith(namedArgs: {'days': '$days'}, when: days != null)
  /// ```
  String trWith({Map<String, String>? namedArgs, bool when = true}) {
    return when ? this.tr(namedArgs: namedArgs) : '';
  }
}
