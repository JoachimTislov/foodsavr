import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../widgets/product/product_card_compact.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/common/retry_scaffold.dart';
import 'product_form_view.dart';
import '../widgets/product/product_card_normal.dart';
import '../widgets/product/product_card_details.dart';
import '../utils/product_add_helper.dart';
import '../utils/view_mode_helper.dart';
import '../widgets/product/view_mode_toggle.dart';
import 'product_detail_view.dart';

class ProductListView extends StatefulWidget {
  final bool showGlobalProducts;

  const ProductListView({super.key, this.showGlobalProducts = false});

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  List<Product> _products = [];
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final IAuthService _authService;
  late final String? _userId;
  ProductViewMode _viewMode = ProductViewMode.normal;
  Map<int, List<String>> _productInventories = {};

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _userId = _authService.getUserId();
  }

  Future<void> _fetchProducts() async {
    List<Product> fetchedProducts;
    if (widget.showGlobalProducts) {
      fetchedProducts = await _productService.getAllProducts();
    } else {
      if (_userId == null && mounted) {
        setState(() => _products = []);
        return;
      }
      fetchedProducts = await _productService.getProducts(_userId);
    }

    if (!widget.showGlobalProducts) {
      try {
        await _loadInventoryNames(fetchedProducts);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'product.inventoryLoadError'.tr(namedArgs: {'error': '$e'}),
              ),
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _products = fetchedProducts;
      });
    }
  }

  Future<void> _loadInventoryNames(List<Product> products) async {
    if (_userId == null) {
      if (mounted) setState(() => _productInventories = {});
      return;
    }

    final productIds = products.map((p) => p.id).toSet();
    final inventoryMap = await _collectionService.getInventoryNamesForProducts(
      _userId,
      productIds,
    );

    if (mounted) {
      setState(() {
        _productInventories = inventoryMap;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = widget.showGlobalProducts
        ? 'dashboard.globalProducts'.tr()
        : 'product.all_products'.tr();

    return RetryScaffold(
      errorMessage: 'product.errorLoading'.tr(),
      onRefresh: _fetchProducts,
      fetchOnInit: true,
      isBodyScrollable: true,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'product_list_fab',
        onPressed: () async {
          final result = await ProductAddHelper.startAddProductFlow(context);
          if (result == true && mounted) {
            await _fetchProducts();
          }
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: Text('product.scanBarcode'.tr()),
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ViewModeToggle(
                    viewMode: _viewMode,
                    onModeChanged: (mode) {
                      setState(() {
                        _viewMode = mode;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateWidget(
                icon: Icons.inventory_2_outlined,
                title: 'product.noProductsFound'.tr(),
                subtitle: 'product.addFirst'.tr(),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(
                top: _viewMode == ProductViewMode.compact ? 4 : 8,
                bottom: 80,
              ),
              sliver: SliverList.builder(
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return _buildProductCard(product);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    // TODO: Potential for simplification by using a single ProductCard widget that adapts based on view mode
    switch (_viewMode) {
      case ProductViewMode.compact:
        return ProductCardCompact(
          product: product,
          onTap: () => _navigateToProductDetail(product),
        );
      case ProductViewMode.normal:
        return ProductCardNormal(
          product: product,
          onTap: () => _navigateToProductDetail(product),
        );
      case ProductViewMode.details:
        return ProductCardDetails(
          product: product,
          onTap: () => _navigateToProductDetail(product),
          inventoryNames: _productInventories[product.id],
          onEdit: () async {
            final result = await ProductFormView.show(
              context,
              product: product,
            );
            if (!mounted) return;
            if (result == true) {
              await _fetchProducts();
            }
          },
          onDelete: () {
            // TODO: Show delete confirmation
            _showDeleteConfirmation(product);
          },
        );
    }
  }

  void _navigateToProductDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailView(product: product),
      ),
    );
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('product.delete'.tr()),
        content: Text(
          'product.deleteConfirmMessage'.tr(namedArgs: {'name': product.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await _productService.deleteProduct(product.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'product.deleted'.tr(namedArgs: {'name': product.name}),
                    ),
                  ),
                );
                await _fetchProducts();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'product.deleteError'.tr(namedArgs: {'error': '$e'}),
                    ),
                  ),
                );
              }
            },
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }
}
