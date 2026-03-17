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

class DynamicCollectionView extends WatchingWidget {
  final CollectionType type;

  const DynamicCollectionView({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final collectionService = getIt<CollectionService>();
    final authService = getIt<IAuthService>();

    final collectionsFutureNotifier = createOnce(() => ValueNotifier<Future<List<Collection>>?>(null));
    final collectionsFuture = watch(collectionsFutureNotifier).value;

    Future<List<Collection>> fetchCollections() async {
      final userId = authService.getUserId();
      if (userId == null) return [];
      final all = await collectionService.getCollectionsForUser(userId);
      return all.where((c) => c.type == type).toList();
    }

    callOnce((_) {
      collectionsFutureNotifier.value = fetchCollections();
    });

    if (collectionsFuture == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
              type == CollectionType.inventory
                  ? 'collection.inventories'.tr()
                  : 'collection.shoppingLists'.tr(),
            ),
          ),
          body: CollectionListView(typeFilter: type),
        );
      },
    );
  }
}
