import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';
import '../../utils/barcode_validator.dart';

/// Inline feedback on the barcode being typed.
class BarcodeFeedback extends StatelessWidget {
  final BarcodeValidity validity;

  const BarcodeFeedback({super.key, required this.validity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (icon, color, message) = switch (validity) {
      BarcodeValidity.validStandard => (
        Icons.check_circle_outline,
        colorScheme.primary,
        'product.lookup.validStandard'.tr(),
      ),
      BarcodeValidity.invalidCheckDigit => (
        Icons.warning_amber_rounded,
        colorScheme.error,
        'product.lookup.invalidCheckDigit'.tr(),
      ),
      BarcodeValidity.validCustom => (
        Icons.info_outline,
        colorScheme.onSurfaceVariant,
        'product.lookup.validCustom'.tr(),
      ),
      BarcodeValidity.invalidFormat => (
        Icons.error_outline,
        colorScheme.error,
        'product.lookup.invalidFormat'.tr(),
      ),
    };
    // A separate, announced node: screen readers hear the feedback change
    // instead of finding it inside the field's label.
    return Semantics(
      container: true,
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: Material3Config.spacing8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
