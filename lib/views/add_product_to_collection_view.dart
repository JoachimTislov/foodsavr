import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../interfaces/i_auth_service.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';

/// Displays user's registered products for adding to a collection.
class AddProductToCollectionView extends StatelessWidget {
  final String collectionId;

  const AddProductToCollectionView({super.key, required this.collectionId});

  /// Static helper to show the sheet.
  static Future<bool?> show(BuildContext context, String collectionId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddProductSheet(collectionId: collectionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This is just a wrapper for the static show method.
    // It should not be used directly in the widget tree.
    return const SizedBox.shrink();
  }
}

class _AddProductSheet extends StatefulWidget with WatchItStatefulWidgetMixin {
  final String collectionId;

  const _AddProductSheet({required this.collectionId});

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> with WatchItMixin {
  static final Random _random = Random();
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final IAuthService _authService;
  late final ValueNotifier<Future<List<Product>>> _productsFuture;
  final _selectedIds = ValueNotifier<Set<int>>(<int>{});
  final _isSaving = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _productsFuture = ValueNotifier<Future<List<Product>>>(_loadProducts());
  }

  @override
  void dispose() {
    _productsFuture.dispose();
    _selectedIds.dispose();
    _isSaving.dispose();
    super.dispose();
  }

  Future<List<Product>> _loadProducts() async {
    final userId = _authService.getUserId();
    if (userId == null) return [];
    final results = await Future.wait([
      _productService.getPersonalProducts(userId),
      _productService.getAllProducts(),
    ]);
    final personalProducts = results[0];
    final globalProducts = results[1];
    return [...personalProducts, ...globalProducts];
  }

  Future<void> _addSelected() async {
    final selectedIds = _selectedIds.value;
    if (selectedIds.isEmpty) return;
    final userId = _authService.getUserId();
    if (userId == null) return;
    _isSaving.value = true;
    try {
      final registryProducts = await _productsFuture.value;
      final selectedProducts = registryProducts
          .where((product) => selectedIds.contains(product.id))
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
      if (mounted) _isSaving.value = false;
    }
  }

  int _generateProductId() {
    return (DateTime.now().microsecondsSinceEpoch * 1000) +
        _random.nextInt(1000);
  }

  @override
  Widget build(BuildContext context) {
    final productsFuture = watch(_productsFuture).value;
    final selectedIds = watch(_selectedIds).value;
    final isSaving = watch(_isSaving).value;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
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
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isSelected = selectedIds.contains(product.id);
                    return CheckboxListTile(
                      title: Text(product.name),
                      subtitle: Text(product.category),
                      value: isSelected,
                      onChanged: (val) {
                        final newSet = Set<int>.from(_selectedIds.value);
                        if (val == true) {
                          newSet.add(product.id);
                        } else {
                          newSet.remove(product.id);
                        }
                        _selectedIds.value = newSet;
                      },
                    );
                  },
                );
              },
            ),
          ),
          _buildFooter(selectedIds.length, isSaving),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'product.registryTitle'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(int selectedCount, bool isSaving) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: selectedCount > 0 && !isSaving ? _addSelected : null,
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('common.add'.tr()),
        ),
      ),
    );
  }
}
