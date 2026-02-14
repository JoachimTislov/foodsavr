import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../widgets/product/product_card_compact.dart';
import '../widgets/product/product_card_normal.dart';
import '../widgets/product/product_card_details.dart';
import 'product_detail_view.dart';

enum ProductViewMode {
  compact,
  normal,
  details,
}

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Product>> _productsFuture;
  late final ProductService _productService;
  ProductViewMode _viewMode = ProductViewMode.normal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          // View mode toggle
          PopupMenuButton<ProductViewMode>(
            icon: Icon(
              _getViewModeIcon(_viewMode),
              color: colorScheme.primary,
            ),
            tooltip: 'Change view mode',
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
                      'Compact',
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
                      'Normal',
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
                      'Details',
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
                    'No products found',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first product to get started',
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
        onPressed: () {
          // TODO: Navigate to add product screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add product feature coming soon!')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
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
          onEdit: () {
            // TODO: Navigate to edit screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edit feature coming soon!')),
            );
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
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _productService.deleteProduct(product.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${product.name} deleted')),
                  );
                  setState(() {
                    _productsFuture = _fetchProducts();
                  });
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting product: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getViewModeIcon(ProductViewMode mode) {
    switch (mode) {
      case ProductViewMode.compact:
        return Icons.view_headline;
      case ProductViewMode.normal:
        return Icons.view_agenda;
      case ProductViewMode.details:
        return Icons.view_day;
    }
  }

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _authService = getIt<IAuthService>();
    _productsFuture = _fetchProducts();
  }

  Future<List<Product>> _fetchProducts() async {
    final userId = _authService.getUserId();
    if (userId != null) {
      return _productService.getProducts(userId);
    }
    // Fallback to global products if no user is logged in
    return _productService.getAllProducts();
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = _fetchProducts();
    });
  }
}
