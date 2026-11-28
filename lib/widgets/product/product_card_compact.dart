import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../controllers/preferences_controller.dart';
import '../../models/product_model.dart';
import '../../constants/product_categories.dart';
import 'product_icon.dart';

class ProductCardCompact extends WatchingWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCardCompact({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final expiringSoonDays = watchPropertyValue(
      (PreferencesController c) => c.expiringSoonDays,
    );
    final status = product.statusWithin(expiringSoonDays);
    final statusColor = status == ProductStatus.fresh
        ? null
        : status.getColor(colorScheme);
    final statusMessage = product.getFriendlyStatus(compact: true);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Status indicator
              if (statusColor != null)
                Container(
                  width: 4,
                  height: 40,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ProductIcon.fromProduct(product, size: 36),
              const SizedBox(width: 12),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.category != null)
                      Text(
                        ProductCategory.label(product.category!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              // Quantity badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'x${product.quantity}', // l10n-ignore
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Expiration info
              if (product.daysUntilExpiration != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    statusMessage,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: statusColor ?? colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
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
