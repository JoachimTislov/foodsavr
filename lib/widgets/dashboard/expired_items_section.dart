import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import '../../routes/page_trail.dart';
import '../../views/product_detail_view.dart';
import 'expiring_item_card.dart';

/// Expired products, oldest first, shown above "Expiring Soon". Renders
/// nothing when [products] is empty.
class ExpiredItemsSection extends StatelessWidget {
  final List<Product> products;

  const ExpiredItemsSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'dashboard.expired'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: 'dashboard.expiredCount'.plural(
                products.length,
                name: 'count',
              ),
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                constraints: const BoxConstraints(minHeight: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${products.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < products.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          ExpiringItemCard(
            product: products[i],
            expired: true,
            onTap: () => PageTrail.push<void>(
              context,
              label: products[i].name,
              builder: (_) => ProductDetailView(product: products[i]),
            ),
          ),
        ],
      ],
    );
  }
}
