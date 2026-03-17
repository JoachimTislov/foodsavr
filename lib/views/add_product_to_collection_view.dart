import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../interfaces/i_auth_service.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';

/// Displays user's registered products for adding to a collection.
class AddProductToCollectionView extends StatelessWidget {
  final String collectionId;

  const AddProductToCollectionView({super.key, required this.collectionId});

  /// Static helper to show the sheet.
  static Future<bool?> show(BuildContext context, String collectionId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddProductSheet(collectionId: collectionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This is just a wrapper for the static show method.
    // It should not be used directly in the widget tree.
    return const SizedBox.shrink();
  }
}

class _AddProductSheet extends WatchingWidget {
  final String collectionId;

  const _AddProductSheet({required this.collectionId});

  @override
  Widget build(BuildContext context) {
    final productService = getIt<ProductService>();
    final collectionService = getIt<CollectionService>();
    final authService = getIt<IAuthService>();

    final productsFutureNotifier = createOnce(
      () => ValueNotifier<Future<List<Product>>?>(null),
    );
    final selectedIds = createOnce(() => ValueNotifier<Set<int>>(<int>{}));
    final isSaving = createOnce(() => ValueNotifier<bool>(false));

    final currentProductsFuture = watch(productsFutureNotifier).value;
    final currentSelectedIds = watch(selectedIds).value;
    final currentIsSaving = watch(isSaving).value;

    Future<List<Product>> loadProducts() async {
      final userId = authService.getUserId();
      if (userId == null) return [];
      final results = await Future.wait([
        productService.getPersonalProducts(userId),
        productService.getAllProducts(),
      ]);
      final personalProducts = results[0];
      final globalProducts = results[1];
      return [...personalProducts, ...globalProducts];
    }

    callOnce((_) {
      productsFutureNotifier.value = loadProducts();
    });

    Future<void> addSelected() async {
      if (currentSelectedIds.isEmpty) return;
      final userId = authService.getUserId();
      if (userId == null) return;

      isSaving.value = true;
      try {
        final registryProducts = await currentProductsFuture!;
        final selectedProducts = registryProducts
            .where((product) => currentSelectedIds.contains(product.id))
            .toList();

        final createdProductIds = <int>[];
        for (final sourceProduct in selectedProducts) {
          final currentProduct = Product(
            id: productService.generateId(),
            name: sourceProduct.name,
            description: sourceProduct.description,
            userId: userId,
            category: sourceProduct.category,
            registryType: 'current',
            mappedFromProductId: sourceProduct.id,
          );
          await productService.addProduct(currentProduct);
          createdProductIds.add(currentProduct.id);
        }
        await collectionService.addProductsToCollection(
          collectionId,
          createdProductIds,
        );
        if (context.mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('common.error_loading_data'.tr())),
          );
        }
      } finally {
        if (context.mounted) isSaving.value = false;
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: currentProductsFuture == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<List<Product>>(
                    future: currentProductsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('common.error_loading_data'.tr()),
                        );
                      }
                      final products = snapshot.data ?? [];
                      if (products.isEmpty) {
                        return Center(
                          child: Text('product.noProductsFound'.tr()),
                        );
                      }
                      return ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final isSelected = currentSelectedIds.contains(
                            product.id,
                          );
                          return CheckboxListTile(
                            title: Text(product.name),
                            subtitle: Text(product.category ?? ''),
                            value: isSelected,
                            onChanged: (val) {
                              final newSet = Set<int>.from(currentSelectedIds);
                              if (val == true) {
                                newSet.add(product.id);
                              } else {
                                newSet.remove(product.id);
                              }
                              selectedIds.value = newSet;
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
          _buildFooter(
            context,
            currentSelectedIds.length,
            currentIsSaving,
            addSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'product.registryTitle'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    int selectedCount,
    bool isSaving,
    VoidCallback onAdd,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: selectedCount > 0 && !isSaving ? onAdd : null,
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.add'.tr()),
        ),
      ),
    );
  }
}
