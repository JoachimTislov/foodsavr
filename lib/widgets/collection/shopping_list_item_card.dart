import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/product_model.dart';

/// A shopping-list row that keeps the bought toggle visible at all times and
/// exposes quick actions through a long press (or the trailing menu button).
class ShoppingListItemCard extends StatelessWidget {
  final Product product;
  final bool bought;

  /// A change to this item is still being saved, so no other one can start.
  final bool busy;
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
    this.busy = false,
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
      onLongPress: busy ? null : () => _showActions(context),
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
              Checkbox(value: bought, onChanged: busy ? null : onBoughtChanged),
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
                    onPressed: busy || product.quantity == 0
                        ? null
                        : onDecrease,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text('${product.quantity}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: busy ? null : onIncrease,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              PopupMenuButton<String>(
                enabled: !busy,
                onSelected: (value) => _run(context, switch (value) {
                  'edit' => onEdit,
                  'move' => onMove,
                  'duplicate' => onDuplicate,
                  _ => onDelete,
                }),
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

  /// Runs a quick action from either menu and reports a failure that its
  /// handler did not.
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    // Captured first: the action can remove this row.
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('common.somethingWentWrong'.tr())),
      );
    }
  }

  Future<void> _showActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('product.edit'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _run(context, onEdit);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: Text('collection.move'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _run(context, onMove);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text('collection.duplicate'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _run(context, onDuplicate);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text('common.delete'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _run(context, onDelete);
              },
            ),
          ],
        ),
      ),
    );
  }
}
