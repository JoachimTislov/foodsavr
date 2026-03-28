import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../constants/collection_config.dart';
import '../../models/collection_model.dart';

/// Header widget for collection detail view
class CollectionHeader extends StatelessWidget {
  final Collection collection;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onBack;

  const CollectionHeader({
    super.key,
    required this.collection,
    this.onEdit,
    this.onDelete,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 24,
        top: MediaQuery.of(context).padding.top + 16,
        right: 24,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        color: CollectionConfig.getColor(collection.type, colorScheme),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (collection.description != null &&
                        collection.description!.isNotEmpty)
                      Text(
                        collection.description!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox.shrink(),
              Row(
                children: [
                  if (onEdit != null)
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ),
          if (collection.productIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'collection.items_count'.tr(
                      namedArgs: {
                        'count': collection.productIds.length.toString(),
                      },
                    ),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
