import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../widgets/product/product_card_compact.dart';
import 'product_form_view.dart';
import '../widgets/product/product_card_normal.dart';
import '../widgets/product/product_card_details.dart';
import '../utils/view_mode_helper.dart';
import 'product_detail_view.dart';

class ProductListView extends StatefulWidget {
  final bool showGlobalProducts;

  const ProductListView({super.key, this.showGlobalProducts = false});

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  late Future<List<Product>> _productsFuture;
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final IAuthService _authService;
  ProductViewMode _viewMode = ProductViewMode.normal;
  bool _isSigningOut = false;
  Map<int, List<String>> _productInventories = {};

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _productsFuture = _fetchProducts();
  }

  Future<List<Product>> _fetchProducts() async {
    List<Product> products;
    if (widget.showGlobalProducts) {
      products = await _productService.getAllProducts();
    } else {
      final userId = _authService.getUserId();
      if (userId == null) return [];
      products = await _productService.getProducts(userId);
    }

    if (!widget.showGlobalProducts) {
      try {
        await _loadInventoryNames(products);
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

    return products;
  }

  Future<void> _loadInventoryNames(List<Product> products) async {
    final userId = _authService.getUserId();
    if (userId == null) {
      if (mounted) setState(() => _productInventories = {});
      return;
    }

    final productIds = products.map((p) => p.id).toSet();
    final inventoryMap = await _collectionService.getInventoryNamesForProducts(
      userId,
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          // View mode toggle
          PopupMenuButton<ProductViewMode>(
            icon: Icon(
              ViewModeHelper.getViewModeIcon(_viewMode),
              color: colorScheme.primary,
            ),
            onSelected: (mode) {
              setState(() {
                _viewMode = mode;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ProductViewMode.compact,
                child: Row(
                  children: [
                    Icon(
                      Icons.view_headline,
                      color: _viewMode == ProductViewMode.compact
                          ? colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'product.compact'.tr(),
                      style: TextStyle(
                        fontWeight: _viewMode == ProductViewMode.compact
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ProductViewMode.normal,
                child: Row(
                  children: [
                    Icon(
                      Icons.view_agenda,
                      color: _viewMode == ProductViewMode.normal
                          ? colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'product.normal'.tr(),
                      style: TextStyle(
                        fontWeight: _viewMode == ProductViewMode.normal
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ProductViewMode.details,
                child: Row(
                  children: [
                    Icon(
                      Icons.view_day,
                      color: _viewMode == ProductViewMode.details
                          ? colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'product.details'.tr(),
                      style: TextStyle(
                        fontWeight: _viewMode == ProductViewMode.details
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isSigningOut ? null : _handleSignOut,
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'product.errorLoading'.tr(),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'product.noProductsFound'.tr(),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'product.addFirst'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          } else {
            final products = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refreshProducts,
              child: ListView.builder(
                padding: EdgeInsets.only(
                  top: _viewMode == ProductViewMode.compact ? 4 : 8,
                  bottom: 80,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _buildProductCard(product);
                },
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'product_list_fab',
        onPressed: () async {
          final scannedBarcode = await context.push<String>('/barcode-scan');
          if (!mounted || scannedBarcode == null || scannedBarcode.isEmpty) {
            return;
          }
          final userId = _authService.getUserId();
          if (userId == null) return;
          try {
            final result = await _productService.addOrIncrementByBarcode(
              userId: userId,
              barcode: scannedBarcode,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result.matchedExisting
                      ? 'product.barcodeMatched'.tr(
                          namedArgs: {'name': result.product.name},
                        )
                      : 'product.barcodeCreated'.tr(
                          namedArgs: {'name': result.product.name},
                        ),
                ),
              ),
            );
            await _refreshProducts();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'product.barcodeAddError'.tr(namedArgs: {'error': '$e'}),
                ),
              ),
            );
          }
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: Text('product.scanBarcode'.tr()),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
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
              _refreshProducts();
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
                setState(() {
                  _productsFuture = _fetchProducts();
                });
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

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = _fetchProducts();
    });
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isSigningOut = true;
    });
    try {
      await _authService.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }
}
