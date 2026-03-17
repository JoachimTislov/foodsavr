import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../interfaces/i_auth_service.dart';
import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../utils/collection_types.dart';
import 'collection_detail_view.dart';
import 'collection_list_view.dart';

class DynamicCollectionView extends StatefulWidget with WatchItStatefulWidgetMixin {
  final CollectionType type;

  const DynamicCollectionView({super.key, required this.type});

  @override
  State<DynamicCollectionView> createState() => _DynamicCollectionViewState();
}

class _DynamicCollectionViewState extends State<DynamicCollectionView> with WatchItMixin {
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

  Future<List<Collection>> _fetchCollections() async {
    final userId = _authService.getUserId();
    if (userId == null) return [];
    final all = await _collectionService.getCollectionsForUser(userId);
    return all.where((c) => c.type == widget.type).toList();
  }

  void _refreshCollections() {
    _collectionsFuture.value = _fetchCollections();
  }

  @override
  Widget build(BuildContext context) {
    final collectionsFuture = watch(_collectionsFuture).value;

    return FutureBuilder<List<Collection>>(
      future: collectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final collections = snapshot.data ?? [];

        if (collections.length == 1) {
          return CollectionDetailView(collection: collections.first);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.type == CollectionType.inventory
                  ? 'collection.inventories'.tr()
                  : 'collection.shoppingLists'.tr(),
            ),
          ),
          body: CollectionListView(typeFilter: widget.type),
        );
      },
    );
  }
}
