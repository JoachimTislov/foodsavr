import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';
import '../../models/collection_model.dart';
import '../../utils/collection_types.dart';
import '../../views/collection_detail_view.dart';
import '../../views/collection_form_view.dart';
import '../collection/collection_card.dart';
import '../collection/collection_kickstart_card.dart';

/// The user's inventories or shopping lists as a dashboard section, with the
/// kickstart for creating the first one.
class DashboardCollectionsSection extends StatelessWidget {
  final CollectionType type;
  final List<Collection> collections;

  /// Product count per collection ID, where known.
  final Map<String, int> productCounts;

  /// Reloads the dashboard after a collection changed.
  final Future<void> Function() onChanged;

  const DashboardCollectionsSection({
    super.key,
    required this.type,
    required this.collections,
    required this.productCounts,
    required this.onChanged,
  });

  Future<void> _create(BuildContext context) async {
    final created = await CollectionFormView.show(context, type: type);
    if (created == true) await onChanged();
  }

  // The dashboard reloads itself once it is uncovered again.
  void _open(BuildContext context, Collection collection) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CollectionDetailView(collection: collection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isShoppingList = type == CollectionType.shoppingList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  isShoppingList
                      ? 'dashboard.shoppingList'.tr()
                      : 'dashboard.myInventory'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // The kickstart offers the first one.
            if (collections.isNotEmpty)
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                tooltip: isShoppingList
                    ? 'collection.add_shopping_list'.tr()
                    : 'collection.add_inventory'.tr(),
                onPressed: () => _create(context),
              ),
          ],
        ),
        const SizedBox(height: Material3Config.spacing8),
        if (collections.isEmpty)
          Center(
            child: CollectionKickstartCard(type: type, onChanged: onChanged),
          )
        else
          for (final collection in collections)
            CollectionCard(
              key: ValueKey(collection.id),
              collection: collection,
              productCount:
                  productCounts[collection.id] ??
                  collection.productIds.toSet().length,
              margin: const EdgeInsets.only(bottom: Material3Config.spacing8),
              onTap: () => _open(context, collection),
            ),
      ],
    );
  }
}
