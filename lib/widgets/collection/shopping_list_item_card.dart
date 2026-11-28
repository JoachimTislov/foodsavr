import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/product_model.dart';

/// A shopping-list row that keeps the bought toggle visible at all times and
/// exposes quick actions through a long press (or the trailing menu button).
class ShoppingListItemCard extends StatelessWidget {
  final Product product;
  final bool bought;
  final ValueChanged<bool?> onBoughtChanged;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onTap;
  final Future<void> Function() onEdit;
  final Future<void> Function() onMove;
  final Future<void> Function() onDuplicate;
  final Future<void> Function() onDelete;

  const ShoppingListItemCard({
    super.key,
    required this.product,
    required this.bought,
    required this.onBoughtChanged,
    required this.onIncrease,
    required this.onDecrease,
    required this.onTap,
    required this.onEdit,
    required this.onMove,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: bought
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Checkbox(value: bought, onChanged: onBoughtChanged),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: bought
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.description.isNotEmpty)
                        Text(
                          product.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: onDecrease,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text('${product.quantity}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: onIncrease,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      await onEdit();
                      break;
                    case 'move':
                      await onMove();
                      break;
                    case 'duplicate':
                      await onDuplicate();
                      break;
                    case 'delete':
                      await onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('product.edit'.tr()),
                  ),
                  PopupMenuItem(
                    value: 'move',
                    child: Text('collection.move'.tr()),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    child: Text('collection.duplicate'.tr()),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('common.delete'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('product.edit'.tr()),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: Text('collection.move'.tr()),
              onTap: () {
                Navigator.pop(context);
                onMove();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text('collection.duplicate'.tr()),
              onTap: () {
                Navigator.pop(context);
                onDuplicate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text('common.delete'.tr()),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
