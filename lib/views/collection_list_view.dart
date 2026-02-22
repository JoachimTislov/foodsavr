import 'package:flutter/material.dart';

import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../widgets/collection/collection_card.dart';
import 'collection_detail_view.dart';

class CollectionListView extends StatefulWidget {
  const CollectionListView({super.key});

  @override
  State<CollectionListView> createState() => _CollectionListViewState();
}

class _CollectionListViewState extends State<CollectionListView> {
  late Future<List<Collection>> _collectionsFuture;
  late final CollectionService _collectionService;

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _collectionsFuture = _fetchCollections();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Inventories'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add collection feature coming soon!')),
              );
            },
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
                    'Error loading inventories',
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
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text('No inventories found', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first inventory to get started',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
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
    );
  }

  Future<List<Collection>> _fetchCollections() async {
    return _collectionService.getCollections();
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
