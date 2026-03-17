import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../interfaces/i_auth_service.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../utils/view_mode_helper.dart';
import '../widgets/product/product_card_details.dart';
import '../widgets/product/product_card_normal.dart';
import '../widgets/product/product_card_compact.dart';
import '../utils/product_add_helper.dart';
import 'product_detail_view.dart';

class ProductListView extends WatchingWidget {
  final bool showGlobalProducts;

  const ProductListView({super.key, this.showGlobalProducts = false});

  @override
  Widget build(BuildContext context) {
    final productService = getIt<ProductService>();
    final collectionService = getIt<CollectionService>();
    final authService = getIt<IAuthService>();

    final productsFutureNotifier = createOnce(
      () => ValueNotifier<Future<List<Product>>?>(null),
    );
    final viewModeNotifier = createOnce(
      () => ValueNotifier<ProductViewMode>(ProductViewMode.normal),
    );
    final isSigningOutNotifier = createOnce(() => ValueNotifier<bool>(false));
    final productInventoriesNotifier = createOnce(
      () => ValueNotifier<Map<int, List<String>>>({}),
    );

    final productsFuture = watch(productsFutureNotifier).value;
    final viewMode = watch(viewModeNotifier).value;
    final isSigningOut = watch(isSigningOutNotifier).value;
    final productInventories = watch(productInventoriesNotifier).value;

    Future<List<Product>> fetchProducts() async {
      if (showGlobalProducts) {
        return productService.getAllProducts();
      }
      final userId = authService.getUserId();
      if (userId == null) return [];
      final products = await productService.getPersonalProducts(userId);

      // Fetch collections to show which inventories products are in
      final collections = await collectionService.getCollectionsForUser(userId);
      final inventoryMap = <int, List<String>>{};
      for (final product in products) {
        final names = collections
            .where((c) => c.productIds.contains(product.id))
            .map((c) => c.name)
            .toList();
        if (names.isNotEmpty) {
          inventoryMap[product.id] = names;
        }
      }
      if (context.mounted) {
        productInventoriesNotifier.value = inventoryMap;
      }

      return products;
    }

    void refreshProducts() {
      productsFutureNotifier.value = fetchProducts();
    }

    callOnce((_) => refreshProducts());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          showGlobalProducts
              ? 'product.globalTitle'.tr()
              : 'product.personalTitle'.tr(),
        ),
        actions: [
          IconButton(
            icon: Icon(ViewModeHelper.getViewModeIcon(viewMode)),
            onPressed: () {
              final nextMode = switch (viewMode) {
                ProductViewMode.normal => ProductViewMode.compact,
                ProductViewMode.compact => ProductViewMode.details,
                ProductViewMode.details => ProductViewMode.normal,
              };
              viewModeNotifier.value = nextMode;
            },
          ),
          IconButton(
            icon: isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            onPressed: isSigningOut
                ? null
                : () async {
                    isSigningOutNotifier.value = true;
                    await authService.signOut();
                    if (context.mounted) isSigningOutNotifier.value = false;
                  },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => refreshProducts(),
        child: productsFuture == null
            ? const Center(child: CircularProgressIndicator())
            : FutureBuilder<List<Product>>(
                future: productsFuture,
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
                    return Center(child: Text('product.noProductsFound'.tr()));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _buildProductCard(
                        context,
                        product,
                        viewMode,
                        productInventories,
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await ProductAddHelper.startAddProductFlow(context);
          if (result == true) {
            refreshProducts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    ProductViewMode viewMode,
    Map<int, List<String>> productInventories,
  ) {
    void navigateToDetail(Product p) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ProductDetailView(product: p)),
      );
    }

    return switch (viewMode) {
      ProductViewMode.compact => ProductCardCompact(
        product: product,
        onTap: () => navigateToDetail(product),
      ),
      ProductViewMode.normal => ProductCardNormal(
        product: product,
        onTap: () => navigateToDetail(product),
      ),
      ProductViewMode.details => ProductCardDetails(
        product: product,
        inventoryNames: productInventories[product.id],
        onTap: () => navigateToDetail(product),
      ),
    };
  }
}
