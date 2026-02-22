import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/product_categories.dart';
import '../../models/product_model.dart';

class ProductCardDetails extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final List<String>? inventoryNames;

  const ProductCardDetails({
    super.key,
    required this.product,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.inventoryNames,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get status from product model
    final status = product.status;
    final statusColor = status.getColor(colorScheme);
    final statusMessage = product.getFriendlyStatus();
    final statusIcon = status.getIcon();

    final daysLeft = product.daysUntilExpiration;
    final friendlyStatus = product.getFriendlyStatus();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with image and title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product icon/image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      ProductCategory.getIcon(product.category),
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title and category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                product.name,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (statusColor != colorScheme.primary) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: statusMessage,
                                child: Icon(
                                  statusIcon,
                                  color: statusColor,
                                  size: 24,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (product.category != null)
                          Chip(
                            label: Text(product.category!),
                            labelStyle: theme.textTheme.labelMedium,
                            backgroundColor: colorScheme.secondaryContainer,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
                  // Action buttons
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit' && onEdit != null) {
                          onEdit!();
                        } else if (value == 'delete' && onDelete != null) {
                          onDelete!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                product.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (inventoryNames != null && inventoryNames!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stored in: ${inventoryNames!.join(", ")}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              // Status banner (Optional - TODO suggested omitting but let's keep it if it has multiple entries)
              if (product.expiries.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              friendlyStatus,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (daysLeft != null)
                              Text(
                                daysLeft < 0
                                    ? 'Expired ${daysLeft.abs()}d ago'
                                    : daysLeft == 0
                                    ? 'Expires today'
                                    : '${daysLeft}d remaining',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: statusColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Details grid
              _buildDetailsGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsGrid(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            context,
            icon: Icons.inventory_2_outlined,
            label: 'Total Quantity',
            value: '${product.quantity}',
          ),
          if (product.expiries.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Expirations',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...product.expiries.map((entry) {
              final isEntryExpired = entry.isExpired;
              final isEntryToday = entry.isExpiringToday;
              final days = entry.daysUntilExpiration;

              String expiryText;
              Color textColor = colorScheme.onSurface;
              if (isEntryExpired) {
                expiryText = 'Expired';
                textColor = colorScheme.error;
              } else if (isEntryToday) {
                expiryText = 'Today';
                textColor = colorScheme.tertiary;
              } else {
                expiryText = DateFormat.yMMMd().format(entry.expirationDate);
                if (days <= 6) textColor = colorScheme.tertiary;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${entry.quantity} units',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      expiryText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: days <= 6 || isEntryExpired
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (product.isGlobal) ...[
            const Divider(height: 24),
            _buildDetailRow(
              context,
              icon: Icons.public,
              label: 'Type',
              value: 'Global Product',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 24, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
