import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:watch_it/watch_it.dart';

import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../utils/collection_types.dart';
import '../widgets/collection/collection_card.dart';
import 'collection_detail_view.dart';
import 'collection_form_view.dart';

class CollectionListView extends WatchingWidget {
  final CollectionType? typeFilter;

  const CollectionListView({super.key, this.typeFilter});

  @override
  Widget build(BuildContext context) {
    final collectionService = getIt<CollectionService>();
    final authService = getIt<IAuthService>();

    final collectionsFutureNotifier = createOnce(
      () => ValueNotifier<Future<List<Collection>>?>(null),
    );
    final collectionsFuture = watch(collectionsFutureNotifier).value;

    Future<List<Collection>> fetchCollections() async {
      final userId = authService.getUserId();
      if (userId == null) return [];

      final all = await collectionService.getCollectionsForUser(userId);
      if (typeFilter == null) return all;

      return all
          .where((c) => collectionTypeFromJson(c.type.name) == typeFilter)
          .toList();
    }

    void refreshCollections() {
      collectionsFutureNotifier.value = fetchCollections();
    }

    callOnce((_) => refreshCollections());

    void navigateToDetail(Collection collection) {
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) =>
                  CollectionDetailView(collection: collection),
            ),
          )
          .then((_) => refreshCollections());
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: collectionsFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Collection>>(
              future: collectionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('common.error_loading_data'.tr()));
                }

                final collections = snapshot.data ?? [];

                if (collections.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          typeFilter == CollectionType.inventory
                              ? Icons.inventory_2_outlined
                              : Icons.shopping_cart_outlined,
                          size: 64,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          typeFilter == CollectionType.inventory
                              ? 'collection.noInventories'.tr()
                              : 'collection.noShoppingLists'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () async {
                            final result = await CollectionFormView.show(
                              context,
                              type: typeFilter ?? CollectionType.inventory,
                            );
                            if (result == true) {
                              refreshCollections();
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: Text(
                            typeFilter == CollectionType.inventory
                                ? 'collection.createInventory'.tr()
                                : 'collection.createShoppingList'.tr(),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => refreshCollections(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: collections.length,
                    itemBuilder: (context, index) {
                      final collection = collections[index];
                      return CollectionCard(
                        collection: collection,
                        onTap: () => navigateToDetail(collection),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: collectionsFuture == null
          ? null
          : FutureBuilder<List<Collection>>(
              future: collectionsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                return FloatingActionButton(
                  heroTag: 'collection_list_fab_${typeFilter?.name ?? 'all'}',
                  onPressed: () async {
                    final result = await CollectionFormView.show(
                      context,
                      type: typeFilter ?? CollectionType.inventory,
                    );
                    if (result == true) {
                      refreshCollections();
                    }
                  },
                  child: const Icon(Icons.add),
                );
              },
            ),
    );
  }
}
