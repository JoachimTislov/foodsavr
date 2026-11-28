import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/product_model.dart';
import '../../views/product_detail_view.dart';
import 'expiring_item_card.dart';
import 'register_expiry_card.dart';

class ExpiringSoonSection extends StatelessWidget {
  final List<Product> products;

  /// Starts registering a new expiry, offered when nothing is expiring.
  final VoidCallback onRegisterExpiry;

  const ExpiringSoonSection({
    super.key,
    required this.products,
    required this.onRegisterExpiry,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.expiringSoon'.tr(),
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (products.isEmpty)
          RegisterExpiryCard(onRegisterExpiry: onRegisterExpiry)
        else
          Column(
            children: [
              for (int i = 0; i < products.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
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
