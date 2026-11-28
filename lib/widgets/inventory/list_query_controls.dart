import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../controllers/list_query.dart';
import '../../controllers/list_query_state.dart';
import '../../models/collection_model.dart';
import '../../models/product_model.dart';
import '../../constants/product_categories.dart';

class ListQueryControls extends StatelessWidget {
  const ListQueryControls({
    super.key,
    required this.state,
    required this.products,
    this.collections = const [],
  });

  final ListQueryState state;
  final List<Product> products;
  final List<Collection> collections;

  @override
  Widget build(BuildContext context) {
    final categories =
        products
            .map((product) => product.category)
            .whereType<String>()
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters sit above the search field so they never crowd it.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final status in ProductStatus.values)
                FilterChip(
                  label: Text(status.getMessage()),
                  selected: state.status == status,
                  onSelected: (selected) => state.update(
                    () => state.status = selected ? status : null,
                  ),
                ),
              if (categories.isNotEmpty || state.category != null)
                PopupMenuButton<String>(
                  tooltip: 'listQuery.category'.tr(),
                  onSelected: (value) => state.update(
                    () => state.category = value.isEmpty ? null : value,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: '',
                      child: Text('listQuery.anyCategory'.tr()),
                    ),
                    for (final category in categories)
                      CheckedPopupMenuItem(
                        value: category,
                        checked: state.category == category,
                        child: Text(ProductCategory.label(category)),
                      ),
                  ],
                  child: Chip(
                    label: Text(
                      state.category == null
                          ? 'listQuery.category'.tr()
                          : ProductCategory.label(state.category!),
                    ),
                  ),
                ),
              if (collections.isNotEmpty || state.collectionId != null)
                PopupMenuButton<String>(
                  tooltip: 'listQuery.collection'.tr(),
                  onSelected: (value) => state.update(
                    () => state.collectionId = value.isEmpty ? null : value,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: '',
                      child: Text('listQuery.anyCollection'.tr()),
                    ),
                    for (final collection in collections)
                      CheckedPopupMenuItem(
                        value: collection.id,
                        checked: state.collectionId == collection.id,
                        child: Text(collection.name),
                      ),
                  ],
                  child: Chip(
                    label: Text(
                      collections
                              .where((item) => item.id == state.collectionId)
                              .firstOrNull
                              ?.name ??
                          'listQuery.collection'.tr(),
                    ),
                  ),
                ),
              PopupMenuButton<ListSort>(
                tooltip: 'listQuery.sort'.tr(),
                onSelected: (value) => state.update(() => state.sort = value),
                itemBuilder: (context) => [
                  for (final sort in ListSort.values)
                    CheckedPopupMenuItem(
                      value: sort,
                      checked: state.sort == sort,
                      child: Text(_sortLabel(sort)),
                    ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.sort),
                  label: Text(_sortLabel(state.sort)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: state.search,
            onChanged: state.searchFor,
            decoration: InputDecoration(
              labelText: 'listQuery.search'.tr(),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(ListSort sort) => switch (sort) {
    ListSort.original => 'listQuery.original'.tr(),
    ListSort.expiry => 'listQuery.expiry'.tr(),
    ListSort.name => 'listQuery.name'.tr(),
  };
}
