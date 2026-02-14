import 'package:flutter/material.dart';
import '../models/product_model.dart';

class ProductDetailView extends StatelessWidget {
  final Product product;

  const ProductDetailView({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine status
    Color? statusColor;
    String? statusMessage;
    IconData? statusIcon;
    if (product.isExpired) {
      statusColor = colorScheme.error;
      statusMessage = 'This product has expired';
      statusIcon = Icons.error_outline;
    } else if (product.isExpiringSoon) {
      statusColor = colorScheme.tertiary;
      statusMessage = 'This product expires soon';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // TODO: Show delete confirmation
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image section
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(product.category),
                  size: 100,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and category
                  Text(
                    product.name,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (product.category != null)
                    Chip(
                      label: Text(product.category!),
                      labelStyle: theme.textTheme.labelLarge,
                      backgroundColor: colorScheme.secondaryContainer,
                      avatar: Icon(
                        _getCategoryIcon(product.category),
                        size: 20,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Status banner
                  if (statusColor != null && statusMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            statusIcon,
                            color: statusColor,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusMessage,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (product.daysUntilExpiration != null)
                                  Text(
                                    product.daysUntilExpiration! < 0
                                        ? 'Expired ${product.daysUntilExpiration!.abs()} days ago'
                                        : '${product.daysUntilExpiration} days remaining',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: statusColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Description section
                  Text(
                    'Description',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Details section
                  Text(
                    'Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailsCard(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
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
          _buildDetailItem(
            context,
            icon: Icons.inventory_2_outlined,
            label: 'Quantity',
            value: '${product.quantity}',
          ),
          const SizedBox(height: 20),
          if (product.expirationDate != null) ...[
            _buildDetailItem(
              context,
              icon: Icons.calendar_today,
              label: 'Expiration Date',
              value: _formatDate(product.expirationDate!),
            ),
            const SizedBox(height: 20),
            _buildDetailItem(
              context,
              icon: Icons.timelapse,
              label: 'Days Until Expiration',
              value: product.daysUntilExpiration != null
                  ? '${product.daysUntilExpiration} days'
                  : 'N/A',
            ),
            const SizedBox(height: 20),
          ],
          _buildDetailItem(
            context,
            icon: product.isGlobal ? Icons.public : Icons.person,
            label: 'Type',
            value: product.isGlobal ? 'Global Product' : 'Personal Product',
          ),
          if (!product.isGlobal) ...[
            const SizedBox(height: 20),
            _buildDetailItem(
              context,
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

  Widget _buildDetailItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    int valueMaxLines = 1,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: valueMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.shopping_bag;

    switch (category.toLowerCase()) {
      case 'fruits':
        return Icons.apple;
      case 'vegetables':
        return Icons.eco;
      case 'dairy':
        return Icons.egg;
      case 'bakery':
        return Icons.bakery_dining;
      case 'pantry':
        return Icons.kitchen;
      default:
        return Icons.shopping_bag;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
