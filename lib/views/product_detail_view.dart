import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart';

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

class _ProductDetailViewState extends State<ProductDetailView>
    with WatchItStatefulWidgetMixin {
  late final CollectionService _collectionService;
  late final ProductService _productService;
  late final IAuthService _authService;
  final _inventoryNames = ValueNotifier<List<String>?>(null);
  final _isLoadingInventories = ValueNotifier<bool>(false);
  late final ValueNotifier<Product> _currentProduct;

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _productService = getIt<ProductService>();
    _authService = getIt<IAuthService>();
    _currentProduct = ValueNotifier<Product>(widget.product);
    _loadInventories();
  }

  @override
  void dispose() {
    _inventoryNames.dispose();
    _isLoadingInventories.dispose();
    _currentProduct.dispose();
    super.dispose();
  }

  Future<void> _loadInventories() async {
    final userId = _authService.getUserId();
    if (userId == null) return;

    _isLoadingInventories.value = true;
    try {
      final inventories = await _collectionService.getInventoriesByProductId(
        userId,
        _currentProduct.value.id,
      );
      if (mounted) {
        _inventoryNames.value = inventories.map((c) => c.name).toList();
        _isLoadingInventories.value = false;
      }
    } catch (e, stack) {
      debugPrint('Failed to load inventories: $e\n$stack');
      if (mounted) {
        _isLoadingInventories.value = false;
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
    final product = watch(_currentProduct).value;
    final isLoadingInventories = watch(_isLoadingInventories).value;
    final inventoryNames = watch(_inventoryNames).value;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get status from product model
    final status = product.status;
    final statusColor = status.getColor(colorScheme);
    final statusMessage = status.getMessage();
    final statusIcon = status.getIcon();

    return Scaffold(
      appBar: AppBar(),
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
                  // Title and actions
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final result = await ProductFormView.show(
                            context,
                            product: _currentProduct.value,
                          );
                          if (result == true && mounted) {
                            final updatedProduct = await _productService
                                .getProductById(_currentProduct.value.id);
                            if (updatedProduct != null) {
                              _currentProduct.value = updatedProduct;
                              _loadInventories();
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: colorScheme.error),
                        onPressed: () => _showDeleteConfirmation(product),
                      ),
                    ],
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
                                      ? 'product.expiredDaysAgo'.tr(
                                          namedArgs: {
                                            'days':
                                                '${product.daysUntilExpiration!.abs()}',
                                          },
                                        )
                                      : 'product.daysRemaining'.tr(
                                          namedArgs: {
                                            'days':
                                                '${product.daysUntilExpiration}',
                                          },
                                        ),
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
                    'product.description'.tr(),
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
                  if (isLoadingInventories)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    )
                  else if (inventoryNames != null &&
                      inventoryNames.isNotEmpty) ...[
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
                                  'inventories': inventoryNames.join(', '),
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
                    'product.details'.tr(),
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
