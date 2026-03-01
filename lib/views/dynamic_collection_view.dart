import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../utils/collection_types.dart';
import 'collection_detail_view.dart';
import 'collection_list_view.dart';

class DynamicCollectionView extends StatefulWidget {
  final CollectionType type;

  const DynamicCollectionView({super.key, required this.type});

  @override
  State<DynamicCollectionView> createState() => _DynamicCollectionViewState();
}

class _DynamicCollectionViewState extends State<DynamicCollectionView> {
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

  Future<List<Collection>> _fetchCollections() async {
    final userId = _authService.getUserId();
    if (userId == null) return [];
    final all = await _collectionService.getCollectionsForUser(userId);
    return all.where((c) => c.type == widget.type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final titleKey = widget.type == CollectionType.shoppingList
        ? 'dashboard.shoppingList'
        : 'dashboard.myInventory';

    return FutureBuilder<List<Collection>>(
      future: _collectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(titleKey.tr())),
            body: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(titleKey.tr())),
            body: Center(child: Text('collection.loadError'.tr())),
          );
        } else {
          final collections = snapshot.data ?? [];
          if (collections.length == 1) {
            return CollectionDetailView(collection: collections.first);
          } else {
            // Includes 0 collections or >1 collections
            return CollectionListView(typeFilter: widget.type);
          }
        }
      },
    );
  }
}
