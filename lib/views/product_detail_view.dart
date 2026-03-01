import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'product_form_view.dart';
import '../constants/product_categories.dart';
import '../models/product_model.dart';
import '../widgets/product/product_details_card.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../interfaces/i_auth_service.dart';

class ProductDetailView extends StatefulWidget {
  final Product product;

  const ProductDetailView({super.key, required this.product});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  late final CollectionService _collectionService;
  late final ProductService _productService;
  late final IAuthService _authService;
  List<String>? _inventoryNames;
  bool _isLoadingInventories = false;
  late Product _currentProduct;

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _productService = getIt<ProductService>();
    _authService = getIt<IAuthService>();
    _currentProduct = widget.product;
    _loadInventories();
  }

  Future<void> _loadInventories() async {
    final userId = _authService.getUserId();
    if (userId == null) return;

    setState(() => _isLoadingInventories = true);
    try {
      final inventories = await _collectionService.getInventoriesByProductId(
        userId,
        _currentProduct.id,
      );
      if (mounted) {
        setState(() {
          _inventoryNames = inventories.map((c) => c.name).toList();
          _isLoadingInventories = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Failed to load inventories: $e\n$stack');
      if (mounted) {
        setState(() => _isLoadingInventories = false);
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

  @override
  Widget build(BuildContext context) {
    final product = _currentProduct;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get status from product model
    final status = product.status;
    final statusColor = status.getColor(colorScheme);
    final statusMessage = status.getMessage();
    final statusIcon = status.getIcon();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await ProductFormView.show(
                context,
                product: _currentProduct,
              );
              if (result == true && mounted) {
                final updatedProduct = await _productService.getProductById(
                  _currentProduct.id,
                );
                if (updatedProduct != null) {
                  setState(() {
                    _currentProduct = updatedProduct;
                  });
                  _loadInventories();
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmation(product),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image section
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Center(
                child: Icon(
                  ProductCategory.getIcon(product.category),
                  size: 100,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and category
                  Text(
                    product.name,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (product.category != null)
                    Chip(
                      label: Text(product.category!),
                      labelStyle: theme.textTheme.labelLarge,
                      backgroundColor: colorScheme.secondaryContainer,
                      avatar: Icon(
                        ProductCategory.getIcon(product.category),
                        size: 20,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Status banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusMessage,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (product.daysUntilExpiration != null)
                                Text(
                                  product.daysUntilExpiration! < 0
                                      ? 'Expired ${product.daysUntilExpiration!.abs()} days ago'
                                      : '${product.daysUntilExpiration} days remaining',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: statusColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Description section
                  Text(
                    'Description',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  if (_isLoadingInventories)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    )
                  else if (_inventoryNames != null &&
                      _inventoryNames!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'product.availableIn'.tr(
                              namedArgs: {
                                'inventories': _inventoryNames!.join(', '),
                              },
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 32),
                  // Details section
                  Text(
                    'Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProductDetailsCard(product: product),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
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
                context.pop(true);
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
