import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../constants/material3_config.dart';
import '../../controllers/preferences_controller.dart';
import '../../models/product_model.dart';

/// Dashboard row for a product that is expiring soon or already expired.
///
/// With [expired] the card is tinted with the error color and reads
/// "Expired N days ago" as in the Claude Design Expired section.
class ExpiringItemCard extends WatchingWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool expired;

  const ExpiringItemCard({
    super.key,
    required this.product,
    this.onTap,
    this.expired = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final expiringSoonDays = watchPropertyValue(
      (PreferencesController c) => c.expiringSoonDays,
    );
    final timeColor = expired
        ? colorScheme.error
        : product.statusWithin(expiringSoonDays).getColor(colorScheme);
    final days = product.daysUntilExpiration;
    final statusText = expired && days != null
        ? 'product.status_expired_days_ago'.tr(
            namedArgs: {'days': days.abs().toString()},
          )
        : product.getFriendlyStatus();
    final radius = BorderRadius.circular(Material3Config.radiusLarge);

    return Material(
      color: expired
          ? Color.alphaBlend(
              colorScheme.error.withValues(alpha: 0.08),
              colorScheme.surfaceContainer,
            )
          : colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: expired
              ? colorScheme.error.withValues(alpha: 0.4)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(Material3Config.spacing16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                statusText,
                style: TextStyle(
                  color: timeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
