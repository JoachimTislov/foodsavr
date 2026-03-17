import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../interfaces/i_auth_service.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../utils/collection_types.dart';
import '../utils/product_add_helper.dart';
import '../widgets/collection/collection_header.dart';
import '../widgets/common/error_state_widget.dart';
import '../widgets/product/product_card_normal.dart';
import 'add_product_to_collection_view.dart';
import 'collection_form_view.dart';
import 'product_detail_view.dart';

class CollectionDetailView extends WatchingWidget {
  final Collection collection;

  const CollectionDetailView({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    final productService = getIt<ProductService>();
    final collectionService = getIt<CollectionService>();
    final authService = getIt<IAuthService>();

    final currentCollectionNotifier = createOnce(() => ValueNotifier<Collection>(collection));
    final productsFutureNotifier = createOnce(() => ValueNotifier<Future<List<Product>>?>(null));

    final currentCollection = watch(currentCollectionNotifier).value;
    final productsFuture = watch(productsFutureNotifier).value;

    Future<List<Product>> fetchProducts() async {
      final productIds = currentCollection.productIds;
      if (productIds.isEmpty) return [];
      final products = <Product>[];
      for (final id in productIds) {
        final product = await productService.getProductById(id);
        if (product != null) products.add(product);
      }
      return products;
    }

    void refreshProducts() {
      productsFutureNotifier.value = fetchProducts();
    }

    Future<void> refreshCollection() async {
      final updated = await collectionService.getCollection(currentCollection.id);
      if (updated != null && context.mounted) {
        currentCollectionNotifier.value = updated;
        refreshProducts();
      }
    }

    callOnce((_) => refreshProducts());

    Future<void> deleteCollection() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('common.delete'.tr()),
          content: Text(
            'product.deleteConfirmMessage'.tr(
              namedArgs: {'name': currentCollection.name},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('common.delete'.tr()),
            ),
          ],
        ),
      );

      if (confirmed == true && context.mounted) {
        try {
          await collectionService.deleteCollection(currentCollection.id);
          if (context.mounted) {
            Navigator.of(context).pop(true);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete: $e')),
            );
          }
        }
      }
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                final result = await CollectionFormView.show(
                  context,
                  type: currentCollection.type,
                  collection: currentCollection,
                );
                if (result == true) {
                  refreshCollection();
                }
              } else if (value == 'delete') {
                deleteCollection();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 20),
                      const SizedBox(width: 8),
                      Text('common.edit'.tr()),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'common.delete'.tr(),
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollectionHeader(collection: currentCollection),
          Expanded(
            child: productsFuture == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<List<Product>>(
                    future: productsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return ErrorStateWidget(
                          message: 'common.error_loading_data'.tr(),
                          onRetry: refreshProducts,
                        );
                      }

                      final products = snapshot.data ?? [];

                      if (products.isEmpty) {
                        return Center(
                          child: Text(
                            'product.noProductsFound'.tr(),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ProductCardNormal(
                            product: product,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProductDetailView(product: product),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'collection_detail_fab_${currentCollection.id}',
        onPressed: () async {
          bool? result;
          if (currentCollection.type == CollectionType.shoppingList) {
            result = await AddProductToCollectionView.show(
              context,
              currentCollection.id,
            );
          } else {
            result = await ProductAddHelper.startAddProductFlow(
              context,
              collectionId: currentCollection.id,
            );
          }
          if (result == true) {
            refreshProducts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
