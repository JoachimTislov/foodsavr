import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';

/// Welcomes an account without collections or products. The dashboard sections
/// below it carry the actions, so none are repeated here.
class AccountKickstartCard extends StatelessWidget {
  const AccountKickstartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card.outlined(
      // Keeps the title and message as separate semantics nodes.
      semanticContainer: false,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Material3Config.radiusExtraLarge),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Material3Config.spacing16),
        child: Row(
          children: [
            Icon(
              Icons.rocket_launch_outlined,
              size: 32,
              color: colorScheme.primary,
            ),
            const SizedBox(width: Material3Config.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'kickstart.account.title'.tr(),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: Material3Config.spacing4),
                  Text(
                    'kickstart.account.message'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
