import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../constants/preferences_config.dart';
import '../controllers/preferences_controller.dart';
import '../service_locator.dart';

/// The date picker for an expiry date. It opens on [initialDate], or just
/// beyond the expiring-soon window.
Future<DateTime?> pickExpiryDate(
  BuildContext context, {
  DateTime? initialDate,
}) {
  final soonDays = getIt.isRegistered<PreferencesController>()
      ? getIt<PreferencesController>().expiringSoonDays
      : PreferencesConfig.defaultExpiringSoonDays;
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    helpText: 'product.expiryDateHelp'.tr(),
    initialDate: initialDate ?? now.add(Duration(days: soonDays + 1)),
    firstDate: now.subtract(const Duration(days: 365)),
    lastDate: now.add(const Duration(days: 365 * 10)),
  );
}
