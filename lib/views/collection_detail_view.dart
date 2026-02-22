import 'package:flutter/material.dart';

import '../models/collection_model.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../widgets/collection/collection_header.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/common/error_state_widget.dart';
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
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('More options coming soon')),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CollectionHeader(collection: widget.collection),
          const Divider(height: 1),
          Expanded(child: _buildProductsList(theme, colorScheme)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add product to collection feature coming soon!'),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductsList(ThemeData theme, ColorScheme colorScheme) {
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const ErrorStateWidget(message: 'Error loading products');
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: 'No products in this collection',
          );
        } else {
          return _buildProductList(snapshot.data!);
        }
      },
    );
  }

  Widget _buildProductList(List<Product> products) {
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
}
