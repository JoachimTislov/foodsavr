import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../constants/product_categories.dart';
import '../../models/product_model.dart';

class ProductCardNormal extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCardNormal({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine status color and message
    Color? statusColor;
    String? statusMessage;
    IconData? statusIcon;

    final daysLeft = product.daysUntilExpiration;
    if (product.isExpired) {
      statusColor = colorScheme.error;
      statusMessage = 'product.status_expired'.tr();
      statusIcon = Icons.error_outline;
    } else if (product.isExpiringToday) {
      statusColor = colorScheme.tertiary;
      statusMessage = 'product.status_today'.tr();
      statusIcon = Icons.warning_amber_rounded;
    } else if (product.isExpiringSoon) {
      statusColor = colorScheme.tertiary;
      statusMessage = 'product.status_days_left'.tr(
        namedArgs: {'days': daysLeft.toString()},
      );
      statusIcon = Icons.warning_amber_rounded;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product icon/image placeholder (Omit icon per TODO if needed, but let's keep the box for now)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ProductCategory.getIcon(product.category),
                  size: 32,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  product.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Simplified Quantity Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            '${product.quantity}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Refined Status and Expiration
                    Row(
                      children: [
                        if (product.category != null) ...[
                          Icon(
                            ProductCategory.getIcon(product.category),
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.category!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (statusColor != null && statusMessage != null) ...[
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusMessage,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else if (daysLeft != null) ...[
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'product.status_days_left'.tr(
                              namedArgs: {'days': daysLeft.toString()},
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
