import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  void _refreshProducts() {
    setState(() {
      _productsFuture = _fetchProducts();
    });
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
        heroTag: 'collection_detail_fab',
        onPressed: () async {
          final result = await context.push(
            '/product-form?collectionId=${widget.collection.id}',
          );
          if (!mounted) return;
          if (result == true) {
            _refreshProducts();
          }
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
          return ErrorStateWidget(
            message: 'collection.errorLoadingProducts'.tr(),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: 'collection.noProducts'.tr(),
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
    final productIds = widget.collection.productIds;
    if (productIds.isEmpty) return [];
    final products = <Product>[];
    for (final id in productIds) {
      final product = await _productService.getProductById(id);
      if (product != null) products.add(product);
    }
    return products;
  }

  void _navigateToProductDetail(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailView(product: product),
      ),
    );
  }
}
