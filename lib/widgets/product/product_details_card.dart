import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../utils/product_helpers.dart';
import 'product_detail_item.dart';

/// Card widget displaying detailed product information
class ProductDetailsCard extends StatelessWidget {
  final Product product;

  const ProductDetailsCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          ProductDetailItem(
            icon: Icons.inventory_2_outlined,
            label: 'Quantity',
            value: '${product.quantity}',
          ),
          const SizedBox(height: 20),
          if (product.expirationDate != null) ...[
            ProductDetailItem(
              icon: Icons.calendar_today,
              label: 'Expiration Date',
              value: ProductHelpers.formatDateFull(product.expirationDate!),
            ),
            const SizedBox(height: 20),
            ProductDetailItem(
              icon: Icons.timelapse,
              label: 'Days Until Expiration',
              value: product.daysUntilExpiration != null
                  ? '${product.daysUntilExpiration} days'
                  : 'N/A',
            ),
            const SizedBox(height: 20),
          ],
          ProductDetailItem(
            icon: product.isGlobal ? Icons.public : Icons.person,
            label: 'Type',
            value: product.isGlobal ? 'Global Product' : 'Personal Product',
          ),
          if (!product.isGlobal) ...[
            const SizedBox(height: 20),
            ProductDetailItem(
              icon: Icons.badge_outlined,
              label: 'Owner ID',
              value: product.userId,
              valueMaxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}
