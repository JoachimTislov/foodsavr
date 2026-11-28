import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../utils/collection_types.dart';
import '../../utils/product_add_helper.dart';
import '../common/kickstart_card.dart';
import 'create_collection_button.dart';

/// The empty state for a user without any collection of [type].
class CollectionKickstartCard extends StatelessWidget {
  final CollectionType type;

  /// Reloads the owner after an action that changed the user's data.
  final Future<void> Function() onChanged;

  const CollectionKickstartCard({
    super.key,
    required this.type,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isShoppingList = type == CollectionType.shoppingList;
    return KickstartCard(
      icon: isShoppingList
          ? Icons.shopping_cart_outlined
          : Icons.inventory_2_outlined,
      title: isShoppingList
          ? 'kickstart.shoppingList.title'.tr()
          : 'kickstart.inventory.title'.tr(),
      message: isShoppingList
          ? 'kickstart.shoppingList.message'.tr()
          : 'kickstart.inventory.message'.tr(),
      actions: [CreateCollectionButton(type: type, onCreated: onChanged)],
      secondaryActions: [
        if (!isShoppingList) ...[
          TextButton.icon(
            onPressed: () => context.go('/dashboard/global-products'),
            icon: const Icon(Icons.public_outlined),
            label: Text('kickstart.browseProducts'.tr()),
          ),
          TextButton.icon(
            onPressed: () async {
              final added = await ProductAddHelper.startAddProductFlow(context);
              if (added == true) await onChanged();
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: Text('product.scanBarcode'.tr()),
          ),
        ],
      ],
    );
  }
}
