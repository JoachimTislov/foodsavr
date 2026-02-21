import 'package:flutter/material.dart';
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
      statusMessage = 'Expired';
      statusIcon = Icons.error_outline;
    } else if (product.isExpiringToday) {
      statusColor = colorScheme.tertiary;
      statusMessage = 'Today';
      statusIcon = Icons.warning_amber_rounded;
    } else if (product.isExpiringSoon) {
      statusColor = colorScheme.tertiary;
      statusMessage = '${daysLeft}d';
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
                              if (statusColor != null) ...[
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: statusMessage ?? '',
                                  child: Icon(
                                    statusIcon,
                                    size: 18,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Quantity badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '×${product.quantity}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
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
                    // Status and expiration
                    Row(
                      children: [
                        if (product.category != null) ...[
                          Text(
                            product.category!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (statusColor != null && statusMessage != null) ...[
                          Text(
                            statusMessage,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
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
                            '${daysLeft}d left',
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
