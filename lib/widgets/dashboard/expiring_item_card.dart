import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';
import '../../models/product_model.dart';

/// Dashboard row for a product that is expiring soon or already expired.
///
/// With [expired] the card is tinted with the error color and reads
/// "Expired N days ago" as in the Claude Design Expired section.
class ExpiringItemCard extends StatelessWidget {
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
    // An upcoming card whose last entry has since expired (the list was
    // loaded before midnight) shows the expired status, not "fresh".
    final expired =
        this.expired ||
        (product.daysUntilFirstExpiry(expired: false) == null &&
            product.daysUntilFirstExpiry(expired: true) != null);
    final timeColor = expired ? colorScheme.error : colorScheme.tertiary;
    final statusText = switch (product.daysUntilFirstExpiry(expired: expired)) {
      null => ProductStatus.fresh.getMessage(),
      0 => 'product.status_today'.tr(),
      final days when expired => 'dashboard.expiredDaysAgo'.plural(
        days.abs(),
        name: 'days',
      ),
      final days => 'product.status_days_remaining'.tr(
        namedArgs: {'days': days.toString()},
      ),
    };
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
                flex: 3,
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
              // Long labels ("Expired 1000 days ago") wrap instead of
              // overflowing at narrow widths or large text scales.
              Flexible(
                flex: 2,
                child: Text(
                  statusText,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: timeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
