import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../widgets/product/product_card_normal.dart';
import 'product_detail_view.dart';

class CollectionDetailView extends StatefulWidget {
  final Collection collection;

  const CollectionDetailView({super.key, required this.collection});

  @override
  State<CollectionDetailView> createState() => _CollectionDetailViewState();
}

class _CollectionDetailViewState extends State<CollectionDetailView> {
  late Future<List<Product>> _productsFuture;
  late final ProductService _productService;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _productsFuture = _fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection.name),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit collection feature coming soon!'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collection header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _getCollectionColor(widget.collection.type, colorScheme),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getCollectionIcon(widget.collection.type),
                      size: 48,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.collection.name,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          if (widget.collection.description != null)
                            Text(
                              widget.collection.description!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.collection.productIds.length} items',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Products list
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading products',
                          style: theme.textTheme.titleLarge,
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
                          'No products in this collection',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                  );
                } else {
                  final products = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCardNormal(
                        product: product,
                        onTap: () => _navigateToProductDetail(product),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add product to collection feature coming soon!'),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Future<List<Product>> _fetchProducts() async {
    // Fetch products by their IDs
    final allProducts = await _productService.getAllProducts();
    return allProducts
        .where((p) => widget.collection.productIds.contains(p.id))
        .toList();
  }

  void _navigateToProductDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailView(product: product),
      ),
    );
  }

  IconData _getCollectionIcon(CollectionType type) {
    switch (type) {
      case CollectionType.inventory:
        return Icons.inventory_2;
      case CollectionType.shoppingList:
        return Icons.shopping_cart;
      case CollectionType.favorites:
        return Icons.favorite;
      case CollectionType.custom:
        return Icons.folder;
    }
  }

  Color _getCollectionColor(CollectionType type, ColorScheme colorScheme) {
    switch (type) {
      case CollectionType.inventory:
        return colorScheme.primaryContainer;
      case CollectionType.shoppingList:
        return colorScheme.tertiaryContainer;
      case CollectionType.favorites:
        return colorScheme.errorContainer.withRed(255).withGreen(200);
      case CollectionType.custom:
        return colorScheme.secondaryContainer;
    }
  }
}
