import 'package:flutter/material.dart';
import '../../models/collection_model.dart';
import '../../utils/collection_helpers.dart';

class CollectionCard extends StatelessWidget {
  final Collection collection;
  final VoidCallback? onTap;
  final int? productCount;

  const CollectionCard({
    super.key,
    required this.collection,
    this.onTap,
    this.productCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get icon and color based on collection type
    final iconData = CollectionHelpers.getIcon(collection.type);
    final containerColor = CollectionHelpers.getColor(collection.type, colorScheme);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  iconData,
                  size: 32,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 20),
              // Collection info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (collection.description != null)
                      Text(
                        collection.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    // Type badge and item count
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            CollectionHelpers.getLabel(collection.type),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${productCount ?? collection.productIds.length} items',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
