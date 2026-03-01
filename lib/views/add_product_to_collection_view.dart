import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../interfaces/i_auth_service.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';

/// Displays user's registered products for adding to a collection.
class AddProductToCollectionView extends StatefulWidget {
  final String collectionId;

  const AddProductToCollectionView({super.key, required this.collectionId});

  /// Shows the product picker as a modal bottom sheet.
  /// Returns `true` if products were added.
  static Future<bool?> show(BuildContext context, String collectionId) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
          child: _AddProductSheet(collectionId: collectionId),
        ),
      ),
    );
  }

  @override
  State<AddProductToCollectionView> createState() =>
      _AddProductToCollectionViewState();
}

class _AddProductToCollectionViewState
    extends State<AddProductToCollectionView> {
  @override
  Widget build(BuildContext context) {
    // This widget exists only for its static show() method.
    // It should not be used directly in the widget tree.
    return const SizedBox.shrink();
  }
}

class _AddProductSheet extends StatefulWidget {
  final String collectionId;

  const _AddProductSheet({required this.collectionId});

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  static final Random _random = Random();
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final IAuthService _authService;
  late Future<List<Product>> _productsFuture;
  final Set<int> _selectedIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _productsFuture = _loadProducts();
  }

  Future<List<Product>> _loadProducts() async {
    final userId = _authService.getUserId();
    if (userId == null) return [];
    final results = await Future.wait([
      _productService.getPersonalProducts(userId),
      _productService.getAllProducts(),
    ]);
    final personalProducts = results[0] as List<Product>;
    final globalProducts = results[1] as List<Product>;
    return [...personalProducts, ...globalProducts];
  }

  Future<void> _addSelected() async {
    if (_selectedIds.isEmpty) return;
    final userId = _authService.getUserId();
    if (userId == null) return;
    setState(() => _isSaving = true);
    try {
      final registryProducts = await _productsFuture;
      final selectedProducts = registryProducts
          .where((product) => _selectedIds.contains(product.id))
          .toList();
      final createdProductIds = <int>[];
      for (final sourceProduct in selectedProducts) {
        final currentProduct = Product(
          id: _generateProductId(),
          name: sourceProduct.name,
          description: sourceProduct.description,
          userId: userId,
          category: sourceProduct.category,
          registryType: 'current',
          mappedFromProductId: sourceProduct.id,
        );
        await _productService.addProduct(currentProduct);
        createdProductIds.add(currentProduct.id);
      }
      await _collectionService.addProductsToCollection(
        widget.collectionId,
        createdProductIds,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error_loading_data'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int _generateProductId() {
    return (DateTime.now().microsecondsSinceEpoch * 1000) + _random.nextInt(1000);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Text(
            'product.select'.tr(),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(),
        Expanded(
          child: FutureBuilder<List<Product>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('common.error_loading_data'.tr()));
              }
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
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
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'product.addFirst'.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final isSelected = _selectedIds.contains(product.id);
                  return ListTile(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(product.id);
                        } else {
                          _selectedIds.add(product.id);
                        }
                      });
                    },
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                    title: Text(product.name),
                    subtitle: product.category != null
                        ? Text(product.category!)
                        : null,
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selectedIds.isEmpty || _isSaving
                  ? null
                  : _addSelected,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('common.add'.tr()),
            ),
          ),
        ),
      ],
    );
  }
}
