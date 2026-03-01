import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../models/product_model.dart';

class ProductCardDetails extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final List<String>? inventoryNames;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ProductCardDetails({
    super.key,
    required this.product,
    this.onTap,
    this.inventoryNames,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = product.status;
    final statusColor = status.getColor(colorScheme);
    final statusIcon = status.getIcon();
    final friendlyStatus = product.getFriendlyStatus();
    final daysLeft = product.daysUntilExpiration;

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (product.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            product.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onEdit != null || onDelete != null)
                    Row(
                      children: [
                        if (onEdit != null)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: onEdit,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (onDelete != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: onDelete,
                            color: colorScheme.error,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Status highlight
              if (daysLeft != null || product.isExpired)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
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
                                    ? 'product.status_expired_days_ago'.tr(
                                        args: [daysLeft.abs().toString()],
                                      )
                                    : daysLeft == 0
                                    ? 'product.status_expires_today'.tr()
                                    : 'product.status_days_remaining'.tr(
                                        args: [daysLeft.toString()],
                                      ),
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
            label: 'product.total_quantity'.tr(),
            value: '${product.quantity}',
          ),
          if (inventoryNames != null && inventoryNames!.isNotEmpty) ...[
            const Divider(height: 24),
            _buildDetailRow(
              context,
              icon: Icons.location_on_outlined,
              label: 'product.status'.tr(), // Or 'Locations' if we had a key
              value: inventoryNames!.join(', '),
            ),
          ],
          if (product.expiries.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'product.expirations'.tr(),
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
                expiryText = 'product.status_expired'.tr();
                textColor = colorScheme.error;
              } else if (isEntryToday) {
                expiryText = 'product.status_today'.tr();
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
                      '${entry.quantity} ${'product.units'.tr()}',
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
              label: 'product.type'.tr(),
              value: 'product.global_product'.tr(),
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
