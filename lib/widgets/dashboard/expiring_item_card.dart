import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../../controllers/preferences_controller.dart';
import '../../models/product_model.dart';

class ExpiringItemCard extends WatchingWidget {
  final Product product;
  final VoidCallback? onTap;

  const ExpiringItemCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final expiringSoonDays = watchPropertyValue(
      (PreferencesController c) => c.expiringSoonDays,
    );
    final timeColor = product
        .statusWithin(expiringSoonDays)
        .getColor(colorScheme);

    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.getFriendlyStatus(),
                    style: TextStyle(
                      color: timeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
