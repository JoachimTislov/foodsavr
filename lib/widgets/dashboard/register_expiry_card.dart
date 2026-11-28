import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';

/// The empty state of "Expiring Soon": nothing is due, and a new expiry can be
/// registered right away.
class RegisterExpiryCard extends StatelessWidget {
  final VoidCallback onRegisterExpiry;

  const RegisterExpiryCard({super.key, required this.onRegisterExpiry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Material3Config.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Material3Config.radiusLarge),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Material3Config.spacing12,
        runSpacing: Material3Config.spacing12,
        children: [
          Text(
            'dashboard.noProductsExpiringSoon'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onRegisterExpiry,
            icon: const Icon(Icons.event_available_outlined),
            label: Text('dashboard.registerExpiry'.tr()),
          ),
        ],
      ),
    );
  }
}
