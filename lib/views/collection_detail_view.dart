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
import '../widgets/common/retry_scaffold.dart';
import '../widgets/common/empty_state_widget.dart';
import 'add_product_to_collection_view.dart';
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
  List<Product> _products = [];
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late Collection _currentCollection;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _currentCollection = widget.collection;
  }

  Future<void> _fetchProducts() async {
    final productIds = _currentCollection.productIds;
    if (productIds.isEmpty) {
      if (mounted) setState(() => _products = []);
      return;
    }

    final products = <Product>[];
    for (final id in productIds) {
      // TODO: optimize by fetching all products in one call instead of individually
      final product = await _productService.getProductById(id);
      if (product != null) products.add(product);
    }

    if (mounted) {
      setState(() {
        _products = products;
      });
    }
  }

  Future<void> _refreshCollectionAndProducts() async {
    final updated = await _collectionService.getCollection(
      _currentCollection.id,
    );
    if (updated != null && mounted) {
      setState(() {
        _currentCollection = updated;
      });
    }
    await _fetchProducts();
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
    return RetryScaffold(
      errorMessage: 'collection.errorLoadingProducts'.tr(),
      onRefresh: _refreshCollectionAndProducts,
      fetchOnInit: true,
      isBodyScrollable: true,
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
            await _refreshCollectionAndProducts();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: CollectionHeader(
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
                  await _refreshCollectionAndProducts();
                }
              },
              onDelete: () => _deleteCollection(),
            ),
          ),
          if (_products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                icon: Icons.inventory_2_outlined,
                title: 'collection.noProducts'.tr(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 80),
              sliver: SliverList.builder(
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return ProductCardNormal(
                    product: product,
                    onTap: () => _navigateToProductDetail(product),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _navigateToProductDetail(Product product) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailView(product: product),
      ),
    );
    // TODO: handle result == false?
    if (result == true && mounted) {
      await _refreshCollectionAndProducts();
    }
  }
}
