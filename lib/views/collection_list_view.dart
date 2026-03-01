import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../utils/collection_types.dart';
import '../widgets/collection/collection_card.dart';
import 'collection_detail_view.dart';

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

    final titleText = widget.typeFilter == CollectionType.shoppingList
        ? 'dashboard.shoppingList'.tr()
        : 'dashboard.myInventories'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () async {
              final result = await context.push(
                '/collection-form',
                extra: {
                  'type': widget.typeFilter ?? CollectionType.inventory,
                  'collection': null,
                },
              );
              if (result == true) {
                _refreshCollections();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<Collection>>(
        future: _collectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'collection.loadError'.tr(),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.typeFilter == CollectionType.shoppingList
                        ? Icons.shopping_cart_outlined
                        : Icons.inventory_2_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'collection.emptyTitle'.tr(),
                    style: theme.textTheme.titleLarge,
                  ),
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
                      final result = await context.push(
                        '/collection-form',
                        extra: {
                          'type': widget.typeFilter ?? CollectionType.inventory,
                          'collection': null,
                        },
                      );
                      if (result == true) {
                        _refreshCollections();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(
                      widget.typeFilter == CollectionType.shoppingList
                          ? 'collection.create_shopping_list'.tr()
                          : 'collection.create_inventory'.tr(),
                    ),
                  ),
                ],
              ),
            );
          } else {
            final collections = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refreshCollections,
              child: ListView.builder(
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'collection_list_fab_${widget.typeFilter?.name ?? 'all'}',
        onPressed: () async {
          final result = await context.push(
            '/collection-form',
            extra: {
              'type': widget.typeFilter ?? CollectionType.inventory,
              'collection': null,
            },
          );
          if (result == true) {
            _refreshCollections();
          }
        },
        child: const Icon(Icons.add),
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
    setState(() {
      _collectionsFuture = _fetchCollections();
    });
  }

  void _navigateToCollectionDetail(Collection collection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CollectionDetailView(collection: collection),
      ),
    );
  }
}
