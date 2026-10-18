import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../controllers/product_list_controller.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
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
import 'receipt_scan_view.dart';

class ProductListView extends StatefulWidget {
  final bool showGlobalProducts;

  const ProductListView({super.key, this.showGlobalProducts = false});

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  late final ProductListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProductListController(
      productService: getIt<ProductService>(),
      collectionService: getIt<CollectionService>(),
      authService: getIt(),
      showGlobalProducts: widget.showGlobalProducts,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts({bool forceRefresh = false}) async {
    await _controller.load(forceRefresh: forceRefresh);
    if (_controller.inventoryLoadError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'product.inventoryLoadError'.tr(
              namedArgs: {'error': '${_controller.inventoryLoadError}'},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _reloadProductsAfterMutation() async {
    try {
      await _fetchProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('product.errorLoading'.tr())));
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
      onRefresh: () => _fetchProducts(forceRefresh: true),
      fetchOnInit: true,
      isBodyScrollable: true,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.showGlobalProducts && _controller.userId != null)
            FloatingActionButton.extended(
              heroTag: 'receipt_scan_fab',
              onPressed: () async {
                final userId = _controller.userId;
                if (userId == null) return;
                final ingested =
                    await Navigator.of(context, rootNavigator: true).push<bool>(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (context) => ReceiptScanView(userId: userId),
                      ),
                    );
                if (ingested == true && mounted) {
                  await _reloadProductsAfterMutation();
                }
              },
              icon: const Icon(Icons.receipt_long),
              label: Text('receipt.scanShort'.tr()),
            ),
          if (!widget.showGlobalProducts && _controller.userId != null)
            const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'product_list_fab',
            onPressed: () async {
              final result = await ProductAddHelper.startAddProductFlow(
                context,
              );
              if (result == true && mounted) {
                await _reloadProductsAfterMutation();
              }
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: Text('product.scanBarcode'.tr()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _buildBody(context, theme, colorScheme, title),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String title,
  ) {
    final products = _controller.products;
    final viewMode = _controller.viewMode;
    return CustomScrollView(
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
                  viewMode: viewMode,
                  onModeChanged: _controller.setViewMode,
                ),
              ],
            ),
          ),
        ),
        if (products.isEmpty)
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
              top: viewMode == ProductViewMode.compact ? 4 : 8,
              bottom: 80,
            ),
            sliver: SliverList.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductCard(product);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    switch (_controller.viewMode) {
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
          inventoryNames: _controller.productInventories[product.id],
          onEdit: () async {
            final result = await ProductFormView.show(
              context,
              product: product,
            );
            if (!mounted) return;
            if (result == true) {
              await _reloadProductsAfterMutation();
            }
          },
          onDelete: () {
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
                await getIt<ProductService>().deleteProduct(product.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'product.deleted'.tr(namedArgs: {'name': product.name}),
                    ),
                  ),
                );
                await _reloadProductsAfterMutation();
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
