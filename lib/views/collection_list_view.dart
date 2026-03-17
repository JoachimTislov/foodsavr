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

class CollectionListView extends StatefulWidget with WatchItStatefulWidgetMixin {
  final CollectionType? typeFilter;

  const CollectionListView({super.key, this.typeFilter});

  @override
  State<CollectionListView> createState() => _CollectionListViewState();
}

class _CollectionListViewState extends State<CollectionListView> with WatchItMixin {
  late final ValueNotifier<Future<List<Collection>>> _collectionsFuture;
  late final CollectionService _collectionService;
  late final IAuthService _authService;

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _collectionsFuture = ValueNotifier<Future<List<Collection>>>(
      _fetchCollections(),
    );
  }

  @override
  void dispose() {
    _collectionsFuture.dispose();
    super.dispose();
  }

  void _refreshCollections() {
    _collectionsFuture.value = _fetchCollections();
  }

  @override
  Widget build(BuildContext context) {
    final collectionsFuture = watch(_collectionsFuture).value;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: FutureBuilder<List<Collection>>(
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
                    widget.typeFilter == CollectionType.inventory
                        ? Icons.inventory_2_outlined
                        : Icons.shopping_cart_outlined,
                    size: 64,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.typeFilter == CollectionType.inventory
                        ? 'collection.noInventories'.tr()
                        : 'collection.noShoppingLists'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await CollectionFormView.show(
                        context,
                        type: widget.typeFilter ?? CollectionType.inventory,
                      );
                      if (result == true) {
                        _refreshCollections();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(
                      widget.typeFilter == CollectionType.inventory
                          ? 'collection.createInventory'.tr()
                          : 'collection.createShoppingList'.tr(),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refreshCollections(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                return CollectionCard(
                  collection: collection,
                  onTap: () => _navigateToDetail(collection),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final collectionsFuture = watch(_collectionsFuture).value;
          return FutureBuilder<List<Collection>>(
            future: collectionsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              return FloatingActionButton(
                heroTag: 'collection_list_fab_${widget.typeFilter?.name ?? 'all'}',
                onPressed: () async {
                  final result = await CollectionFormView.show(
                    context,
                    type: widget.typeFilter ?? CollectionType.inventory,
                  );
                  if (result == true) {
                    _refreshCollections();
                  }
                },
                child: const Icon(Icons.add),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Collection>> _fetchCollections() async {
    final userId = _authService.getUserId();
    if (userId == null) return [];

    final all = await _collectionService.getCollectionsForUser(userId);
    if (widget.typeFilter == null) return all;

    return all.where((c) => collectionTypeFromJson(c.type.name) == widget.typeFilter).toList();
  }

  void _navigateToDetail(Collection collection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CollectionDetailView(collection: collection),
      ),
    ).then((_) => _refreshCollections());
  }
}
