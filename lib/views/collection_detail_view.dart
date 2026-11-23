import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../controllers/list_query_state.dart';
import '../controllers/preferences_controller.dart';
import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../utils/collection_types.dart';
import '../utils/product_add_helper.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../widgets/collection/collection_header.dart';
import '../widgets/common/content_constraint.dart';
import '../widgets/common/retry_scaffold.dart';
import '../widgets/common/empty_state_widget.dart';
import 'add_product_to_collection_view.dart';
import '../widgets/inventory/list_query_controls.dart';
import '../widgets/product/product_card_compact.dart';
import '../widgets/product/product_card_details.dart';
import '../widgets/product/product_card_normal.dart';
import '../widgets/product/view_mode_toggle.dart';
import '../utils/view_mode_helper.dart';
import 'product_detail_view.dart';
import 'collection_form_view.dart';

class CollectionDetailView extends StatefulWidget {
  final Collection collection;

  /// When set, the view is embedded beside a list: it has no back button and
  /// reports an edited collection, or null once it was deleted.
  final ValueChanged<Collection?>? onChanged;

  const CollectionDetailView({
    super.key,
    required this.collection,
    this.onChanged,
  });

  @override
  State<CollectionDetailView> createState() => _CollectionDetailViewState();
}

class _CollectionDetailViewState extends State<CollectionDetailView> {
  List<Product> _products = [];
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late Collection _currentCollection;
  late final ListQueryState _query;
  late final PreferencesController _preferences;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _currentCollection = widget.collection;
    _preferences = getIt<PreferencesController>();
    _query = ListQueryState(
      'collection.${widget.collection.userId}.${widget.collection.id}',
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    final productIds = _currentCollection.productIds;
    if (productIds.isEmpty) {
      if (mounted) setState(() => _products = []);
      return;
    }

    final results = await Future.wait(
      productIds.map((id) => _productService.getProductById(id)),
    );
    final products = results.whereType<Product>().toList();

    if (mounted) {
      setState(() {
        _products = products;
      });
    }
  }

  Future<void> _refreshCollectionAndProducts() async {
    await _query.restore();
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
          final onChanged = widget.onChanged;
          if (onChanged == null) {
            Navigator.of(context).pop(true);
          } else {
            onChanged(null);
          }
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
      body: ListenableBuilder(
        listenable: Listenable.merge([_query, _preferences]),
        builder: (context, _) => _buildCollection(context),
      ),
    );
  }

  Widget _buildCollection(BuildContext context) {
    final products = _query.query.apply(
      _products,
      now: DateTime.now(),
      expiringSoonDays: _preferences.expiringSoonDays,
    );
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverContentConstraint(
          slivers: [
            SliverToBoxAdapter(
              child: CollectionHeader(
                collection: _currentCollection,
                onBack:
                    widget.onChanged == null && Navigator.of(context).canPop()
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
                    if (mounted) widget.onChanged?.call(_currentCollection);
                  }
                },
                onDelete: () => _deleteCollection(),
              ),
            ),
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerRight,
                child: ViewModeToggle(
                  viewMode: _query.viewMode,
                  onModeChanged: (mode) =>
                      _query.update(() => _query.viewMode = mode),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ListQueryControls(state: _query, products: _products),
            ),
            if (products.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 80),
                sliver: SliverList.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    void open() => _navigateToProductDetail(product);
                    return switch (_query.viewMode) {
                      ProductViewMode.compact => ProductCardCompact(
                        product: product,
                        onTap: open,
                      ),
                      ProductViewMode.normal => ProductCardNormal(
                        product: product,
                        onTap: open,
                      ),
                      ProductViewMode.details => ProductCardDetails(
                        product: product,
                        onTap: open,
                      ),
                    };
                  },
                ),
              ),
          ],
        ),
        if (products.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyStateWidget(
              icon: Icons.inventory_2_outlined,
              title: _products.isEmpty
                  ? 'collection.noProducts'.tr()
                  : 'listQuery.noMatches'.tr(),
            ),
          ),
      ],
    );
  }

  Future<void> _navigateToProductDetail(Product product) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailView(product: product),
      ),
    );
    if (result == true && mounted) {
      await _refreshCollectionAndProducts();
    }
  }
}
