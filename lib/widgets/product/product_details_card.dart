import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/product_model.dart';
import 'product_detail_item.dart';

/// Card widget displaying detailed product information
class ProductDetailsCard extends StatelessWidget {
  final Product product;

  const ProductDetailsCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Column(
        children: [
          ProductDetailItem(
            icon: Icons.inventory_2_outlined,
            label: 'product.total_quantity'.tr(),
            value: '${product.quantity}',
          ),
          const SizedBox(height: 20),
          if (product.soonestExpirationDate != null) ...[
            ProductDetailItem(
              icon: Icons.calendar_today,
              label: 'product.soonest_expiration'.tr(),
              value: DateFormat.yMMMMd().format(product.soonestExpirationDate!),
            ),
            const SizedBox(height: 20),
            ProductDetailItem(
              icon: Icons.timelapse,
              label: 'product.days_until_soonest_expiry'.tr(),
              value: product.daysUntilExpiration != null
                  ? product.daysUntilExpiration! < 0
                        ? 'product.status_expired_days_ago'.tr(
                            namedArgs: {
                              'days': product.daysUntilExpiration!
                                  .abs()
                                  .toString(),
                            },
                          )
                        : product.daysUntilExpiration! == 0
                        ? 'product.status_today'.tr()
                        : 'product.status_days'.tr(
                            namedArgs: {
                              'days': product.daysUntilExpiration.toString(),
                            },
                          )
                  : 'product.na'.tr(),
            ),
            const SizedBox(height: 20),
          ],
          if (product.expiries.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'product.expiration_breakdown'.tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...product.expiries.map((entry) {
              final isExpired = entry.isExpired;
              final isWarning = !isExpired && entry.daysUntilExpiration <= 6;
              final statusColor = isExpired
                  ? colorScheme.error
                  : isWarning
                  ? colorScheme.tertiary
                  : colorScheme.primary;
              final statusIcon = isExpired
                  ? Icons.error_outline
                  : isWarning
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline;

              return Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${entry.quantity} ${'product.units'.tr()}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat.yMMMd().format(entry.expirationDate),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 16),
          ],
          ProductDetailItem(
            icon: product.isGlobal ? Icons.public : Icons.person,
            label: 'product.type'.tr(),
            value: product.isGlobal
                ? 'product.global_product'.tr()
                : 'product.personal_product'.tr(),
          ),
        ],
      ),
    );
  }
}
