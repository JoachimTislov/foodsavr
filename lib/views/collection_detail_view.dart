import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../utils/collection_types.dart';
import '../utils/product_add_helper.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../widgets/collection/collection_header.dart';
import '../widgets/common/app_refresh_indicator.dart';
import '../widgets/common/empty_state_widget.dart';
import 'add_product_to_collection_view.dart';
import '../widgets/common/error_state_widget.dart';
import '../widgets/product/product_card_normal.dart';
import 'product_detail_view.dart';
import 'collection_form_view.dart';

class CollectionDetailView extends StatefulWidget {
  final Collection collection;

  const CollectionDetailView({super.key, required this.collection});

  @override
  State<CollectionDetailView> createState() => _CollectionDetailViewState();
}

class _CollectionDetailViewState extends State<CollectionDetailView> {
  late Future<List<Product>> _productsFuture;
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late Collection _currentCollection;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _currentCollection = widget.collection;
    _productsFuture = _fetchProducts();
  }

  Future<void> _refreshProducts() async {
    final future = _fetchProducts();
    setState(() {
      _productsFuture = future;
    });
    await future;
  }

  Future<void> _refreshCollection() async {
    final updated = await _collectionService.getCollection(
      _currentCollection.id,
    );
    if (updated != null && mounted) {
      setState(() {
        _currentCollection = updated;
      });
      await _refreshProducts();
    }
  }

  Future<void> _deleteCollection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('common.delete'.tr()),
        content: Text(
          'product.deleteConfirmMessage'.tr(
            namedArgs: {'name': _currentCollection.name},
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

    if (confirmed == true && mounted) {
      try {
        await _collectionService.deleteCollection(_currentCollection.id);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollectionHeader(
            collection: _currentCollection,
            onBack: Navigator.of(context).canPop()
                ? () => Navigator.of(context).pop()
                : null,
            onEdit: () async {
              final result = await CollectionFormView.show(
                context,
                type: _currentCollection.type,
                collection: _currentCollection,
              );
              if (result == true) {
                _refreshCollection();
              }
            },
            onDelete: () => _deleteCollection(),
          ),
          Expanded(
            child: _ProductsList(
              productsFuture: _productsFuture,
              onRefresh: _refreshCollection,
              onProductTap: _navigateToProductDetail,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'collection_detail_fab_${_currentCollection.id}',
        onPressed: () async {
          bool? result;
          if (_currentCollection.type == CollectionType.shoppingList) {
            result = await AddProductToCollectionView.show(
              context,
              _currentCollection.id,
            );
          } else {
            result = await ProductAddHelper.startAddProductFlow(
              context,
              collectionId: _currentCollection.id,
            );
          }
          if (!mounted) return;
          if (result == true) {
            _refreshProducts();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<List<Product>> _fetchProducts() async {
    final productIds = _currentCollection.productIds;
    if (productIds.isEmpty) return [];
    final products = <Product>[];
    for (final id in productIds) {
      final product = await _productService.getProductById(id);
      if (product != null) products.add(product);
    }
    return products;
  }

  void _navigateToProductDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailView(product: product),
      ),
    );
  }
}

class _ProductsList extends StatelessWidget {
  final Future<List<Product>> productsFuture;
  final Future<void> Function() onRefresh;
  final void Function(Product) onProductTap;

  const _ProductsList({
    required this.productsFuture,
    required this.onRefresh,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AppRefreshIndicator(
            onRefresh: onRefresh,
            isScrollable: false,
            child: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return AppRefreshIndicator(
            onRefresh: onRefresh,
            isScrollable: false,
            child: ErrorStateWidget(
              message: 'collection.errorLoadingProducts'.tr(),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return AppRefreshIndicator(
            onRefresh: onRefresh,
            isScrollable: false,
            child: EmptyStateWidget(
              icon: Icons.inventory_2_outlined,
              title: 'collection.noProducts'.tr(),
            ),
          );
        } else {
          return AppRefreshIndicator(
            onRefresh: onRefresh,
            isScrollable: true,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final product = snapshot.data![index];
                return ProductCardNormal(
                  product: product,
                  onTap: () => onProductTap(product),
                );
              },
            ),
          );
        }
      },
    );
  }
}
