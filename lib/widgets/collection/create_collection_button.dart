import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../utils/collection_create_flow.dart';
import '../../utils/collection_types.dart';

/// Creates a [type] collection under a default name and opens it for renaming.
class CreateCollectionButton extends StatelessWidget {
  final CollectionType type;
  final Future<void> Function() onCreated;

  /// Renders the less prominent tonal style, for a second choice.
  final bool tonal;

  const CreateCollectionButton({
    super.key,
    required this.type,
    required this.onCreated,
    this.tonal = false,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> create() async {
      final created = await CollectionCreateFlow.run(context, type);
      if (created != null) await onCreated();
    }

    final isShoppingList = type == CollectionType.shoppingList;
    final icon = Icon(
      isShoppingList ? Icons.add_shopping_cart : Icons.add_home_outlined,
    );
    final label = Text(
      isShoppingList
          ? 'collection.create_shopping_list'.tr()
          : 'collection.create_inventory'.tr(),
    );
    return tonal
        ? FilledButton.tonalIcon(onPressed: create, icon: icon, label: label)
        : FilledButton.icon(onPressed: create, icon: icon, label: label);
  }
}
