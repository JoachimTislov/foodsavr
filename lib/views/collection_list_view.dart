import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:foodsavr/interfaces/i_auth_service.dart';

import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../utils/collection_types.dart';
import '../widgets/collection/collection_card.dart';
import '../widgets/common/retry_scaffold.dart';
import 'collection_detail_view.dart';
import 'collection_form_view.dart';

class CollectionListView extends StatefulWidget {
  final CollectionType? typeFilter;

  const CollectionListView({super.key, this.typeFilter});

  @override
  State<CollectionListView> createState() => _CollectionListViewState();
}

class _CollectionListViewState extends State<CollectionListView> {
  List<Collection> _collections = [];
  late final CollectionService _collectionService;

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
  }

  // similar to collection detail view
  Future<void> _fetchCollections() async {
    var userId = getIt<IAuthService>().getUserId();
    if (userId == null) {
      if (mounted) setState(() => _collections = []);
      return;
    }

    //  TODO: fetching all collections and then filtering is inefficient, should add filter to service method
    final all = await _collectionService.getCollectionsForUser(userId);
    final filtered = widget.typeFilter != null
        ? all.where((c) => c.type == widget.typeFilter).toList()
        : all.where((c) => c.type == CollectionType.inventory).toList();

    if (mounted) {
      setState(() {
        _collections = filtered;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RetryScaffold(
      errorMessage: 'collection.loadError'.tr(),
      onRefresh: _fetchCollections,
      fetchOnInit: true,
      isBodyScrollable: true,
      floatingActionButton: _collections.isEmpty
          ? const SizedBox.shrink()
          : FloatingActionButton(
              heroTag:
                  'collection_list_fab_${widget.typeFilter?.name ?? 'all'}',
              onPressed: () async {
                final result = await CollectionFormView.show(
                  context,
                  type: widget.typeFilter ?? CollectionType.inventory,
                );
                if (!mounted) return;
                // TODO: handle false, write rg 'result == true' from root dir
                if (result == true) {
                  await _fetchCollections(); // Refetch if modified
                }
              },
              child: const Icon(Icons.add),
            ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
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
          ),
          if (_collections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyCollectionListState(
                typeFilter: widget.typeFilter,
                onRefresh: _fetchCollections,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              sliver: SliverList.builder(
                itemCount: _collections.length,
                itemBuilder: (context, index) {
                  final collection = _collections[index];
                  return CollectionCard(
                    collection: collection,
                    onTap: () => _navigateToCollectionDetail(collection),
                  );
                },
              ),
            ),
        ],
      ),
    );
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
  final Future<void> Function() onRefresh;

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
                await onRefresh();
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
