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
                            args: [
                              product.daysUntilExpiration!.abs().toString(),
                            ],
                          )
                        : product.daysUntilExpiration! == 0
                        ? 'product.status_today'.tr()
                        : 'product.status_days'.tr(
                            args: [product.daysUntilExpiration.toString()],
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
            const SizedBox(height: 12),
            ...product.expiries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${entry.quantity} ${'product.units'.tr()}'),
                    Text(
                      DateFormat.yMMMd().format(entry.expirationDate),
                      style: TextStyle(
                        color: entry.isExpired
                            ? colorScheme.error
                            : entry.daysUntilExpiration <= 6
                            ? colorScheme.tertiary
                            : null,
                        fontWeight: entry.daysUntilExpiration <= 6
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
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
