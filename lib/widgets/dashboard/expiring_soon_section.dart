import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../models/product_model.dart';
import '../../views/product_detail_view.dart';
import 'expiring_item_card.dart';

class ExpiringSoonSection extends StatelessWidget {
  final List<Product> products;

  const ExpiringSoonSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'dashboard.expiringSoon'.tr(),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/dashboard/product-list'),
              child: Text('common.viewAll'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (products.isEmpty)
          Text(
            'dashboard.noProductsExpiringSoon'.tr(),
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < products.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                ExpiringItemCard(
                  product: products[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailView(product: products[i]),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
