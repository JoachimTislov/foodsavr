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

class ProductListView extends StatefulWidget with WatchItStatefulWidgetMixin {
  final bool showGlobalProducts;

  const ProductListView({super.key, this.showGlobalProducts = false});

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> with WatchItMixin {
  late final ValueNotifier<Future<List<Product>>> _productsFuture;
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final IAuthService _authService;
  final _viewMode = ValueNotifier<ProductViewMode>(ProductViewMode.normal);
  final _isSigningOut = ValueNotifier<bool>(false);
  final _productInventories = ValueNotifier<Map<int, List<String>>>({});

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _productsFuture = ValueNotifier<Future<List<Product>>>(_fetchProducts());
  }

  @override
  void dispose() {
    _productsFuture.dispose();
    _viewMode.dispose();
    _isSigningOut.dispose();
    _productInventories.dispose();
    super.dispose();
  }

  void _refreshProducts() {
    _productsFuture.value = _fetchProducts();
  }

  Future<List<Product>> _fetchProducts() async {
    if (widget.showGlobalProducts) {
      return _productService.getAllProducts();
    }
    final userId = _authService.getUserId();
    if (userId == null) return [];
    final products = await _productService.getPersonalProducts(userId);

    // Fetch collections to show which inventories products are in
    final collections = await _collectionService.getCollectionsForUser(userId);
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
    if (mounted) {
      _productInventories.value = inventoryMap;
    }

    return products;
  }

  @override
  Widget build(BuildContext context) {
    final productsFuture = watch(_productsFuture).value;
    final viewMode = watch(_viewMode).value;
    final isSigningOut = watch(_isSigningOut).value;
    final productInventories = watch(_productInventories).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showGlobalProducts
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
              _viewMode.value = nextMode;
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
                    _isSigningOut.value = true;
                    await _authService.signOut();
                    if (mounted) _isSigningOut.value = false;
                  },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshProducts(),
        child: FutureBuilder<List<Product>>(
          future: productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('common.error_loading_data'.tr()));
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
                return _buildProductCard(product, viewMode, productInventories);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await ProductAddHelper.startAddProductFlow(context);
          if (result == true) {
            _refreshProducts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductCard(
    Product product,
    ProductViewMode viewMode,
    Map<int, List<String>> productInventories,
  ) {
    return switch (viewMode) {
      ProductViewMode.compact => ProductCardCompact(
          product: product,
          onTap: () => _navigateToDetail(product),
        ),
      ProductViewMode.normal => ProductCardNormal(
          product: product,
          onTap: () => _navigateToDetail(product),
        ),
      ProductViewMode.details => ProductCardDetails(
          product: product,
          inventoryNames: productInventories[product.id],
          onTap: () => _navigateToDetail(product),
        ),
    };
  }

  void _navigateToDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailView(product: product),
      ),
    );
  }
}
