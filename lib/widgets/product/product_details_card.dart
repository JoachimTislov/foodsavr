import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
            label: 'Total Quantity',
            value: '${product.quantity}',
          ),
          const SizedBox(height: 20),
          if (product.soonestExpirationDate != null) ...[
            ProductDetailItem(
              icon: Icons.calendar_today,
              label: 'Soonest Expiration',
              value: DateFormat.yMMMMd().format(product.soonestExpirationDate!),
            ),
            const SizedBox(height: 20),
            ProductDetailItem(
              icon: Icons.timelapse,
              label: 'Days Until Soonest Expiry',
              value: product.daysUntilExpiration != null
                  ? product.daysUntilExpiration! < 0
                        ? 'Expired ${product.daysUntilExpiration!.abs()} days ago'
                        : product.daysUntilExpiration! == 0
                        ? 'Today'
                        : '${product.daysUntilExpiration} days'
                  : 'N/A',
            ),
            const SizedBox(height: 20),
          ],
          if (product.expiries.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Expiration Breakdown',
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
                    Text('${entry.quantity} units'),
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
            label: 'Type',
            value: product.isGlobal ? 'Global Product' : 'Personal Product',
          ),
        ],
      ),
    );
  }
}
