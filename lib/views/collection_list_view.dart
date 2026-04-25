import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../utils/collection_types.dart';
import '../widgets/collection/collection_card.dart';
import '../widgets/common/app_refresh_indicator.dart';
import 'collection_detail_view.dart';
import '../widgets/common/error_state_widget.dart';
import 'collection_form_view.dart';

class CollectionListView extends StatefulWidget {
  final CollectionType? typeFilter;

  const CollectionListView({super.key, this.typeFilter});

  @override
  State<CollectionListView> createState() => _CollectionListViewState();
}

class _CollectionListViewState extends State<CollectionListView> {
  late Future<List<Collection>> _collectionsFuture;
  late final CollectionService _collectionService;
  late final IAuthService _authService;

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _collectionsFuture = _fetchCollections();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: EdgeInsets.only(
              left: 24,
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.typeFilter == CollectionType.shoppingList
                      ? 'dashboard.shoppingList'.tr()
                      : 'dashboard.myInventory'.tr(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Collection>>(
              future: _collectionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AppRefreshIndicator(
                    onRefresh: _refreshCollections,
                    isScrollable: false,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  return AppRefreshIndicator(
                    onRefresh: _refreshCollections,
                    isScrollable: false,
                    child: ErrorStateWidget(
                      message: 'collection.loadError'.tr(),
                      details: '${snapshot.error}',
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return AppRefreshIndicator(
                    onRefresh: _refreshCollections,
                    isScrollable: false,
                    child: _EmptyCollectionListState(
                      typeFilter: widget.typeFilter,
                      onRefresh: _refreshCollections,
                    ),
                  );
                } else {
                  final collections = snapshot.data!;
                  return AppRefreshIndicator(
                    onRefresh: _refreshCollections,
                    isScrollable: true,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 12, bottom: 20),
                      itemCount: collections.length,
                      itemBuilder: (context, index) {
                        final collection = collections[index];
                        return CollectionCard(
                          collection: collection,
                          onTap: () => _navigateToCollectionDetail(collection),
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<List<Collection>>(
        future: _collectionsFuture,
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
              if (!mounted) return;
              if (result == true) {
                _refreshCollections();
              }
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  Future<List<Collection>> _fetchCollections() async {
    final userId = _authService.getUserId();
    if (userId == null) return [];
    final all = await _collectionService.getCollectionsForUser(userId);
    if (widget.typeFilter != null) {
      return all.where((c) => c.type == widget.typeFilter).toList();
    }
    return all.where((c) => c.type == CollectionType.inventory).toList();
  }

  Future<void> _refreshCollections() async {
    final future = _fetchCollections();
    setState(() {
      _collectionsFuture = future;
    });
    await future;
  }

  void _navigateToCollectionDetail(Collection collection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CollectionDetailView(collection: collection),
      ),
    );
  }
}

class _EmptyCollectionListState extends StatelessWidget {
  final CollectionType? typeFilter;
  final VoidCallback onRefresh;

  const _EmptyCollectionListState({
    required this.typeFilter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            typeFilter == CollectionType.shoppingList
                ? Icons.shopping_cart_outlined
                : Icons.inventory_2_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('collection.emptyTitle'.tr(), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'collection.emptySubtitle'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final result = await CollectionFormView.show(
                context,
                type: typeFilter ?? CollectionType.inventory,
              );
              if (context.mounted && result == true) {
                onRefresh();
              }
            },
            icon: const Icon(Icons.add),
            label: Text(
              typeFilter == CollectionType.shoppingList
                  ? 'collection.create_shopping_list'.tr()
                  : 'collection.create_inventory'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}
