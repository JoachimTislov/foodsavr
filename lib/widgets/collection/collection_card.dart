import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../constants/collection_config.dart';
import '../../constants/material3_config.dart';
import '../../models/collection_model.dart';

class CollectionCard extends StatelessWidget {
  final Collection collection;
  final VoidCallback? onTap;
  final int productCount;

  /// Space around the card; the default suits a full-width list.
  final EdgeInsetsGeometry margin;

  const CollectionCard({
    super.key,
    required this.collection,
    this.onTap,
    required this.productCount,
    this.margin = const EdgeInsets.symmetric(
      horizontal: Material3Config.spacing16,
      vertical: Material3Config.spacing8,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final description = collection.description;

    return Card(
      elevation: 1,
      margin: margin,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Material3Config.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(Material3Config.spacing12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CollectionConfig.getColor(
                    collection.type,
                    colorScheme,
                  ),
                  borderRadius: BorderRadius.circular(
                    Material3Config.radiusMedium,
                  ),
                ),
                child: Icon(
                  CollectionConfig.getIcon(collection.type),
                  size: 24,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: Material3Config.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            collection.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Material3Config.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Material3Config.spacing8,
                            vertical: Material3Config.spacing2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(
                              Material3Config.radiusSmall,
                            ),
                          ),
                          child: Text(
                            'collection.items_count'.tr(
                              namedArgs: {'count': productCount.toString()},
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (description != null && description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: Material3Config.spacing2,
                        ),
                        child: Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
