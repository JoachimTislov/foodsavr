import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../utils/collection_types.dart';
import '../../views/collection_form_view.dart';

/// Opens the create dialog for a [type] collection, named by the user.
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
      final created = await CollectionFormView.show(context, type: type);
      if (created == true) await onCreated();
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
