import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/product_model.dart';
import '../../routes/page_trail.dart';
import '../../views/product_detail_view.dart';
import 'expiring_item_card.dart';

/// Products expiring within the user's window, soonest first. Renders nothing
/// when [products] is empty: the insight tiles already report the count and
/// offer to register an expiry.
class ExpiringSoonSection extends StatelessWidget {
  final List<Product> products;

  const ExpiringSoonSection({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'dashboard.expiringSoon'.tr(),
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < products.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          ExpiringItemCard(
            product: products[i],
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
