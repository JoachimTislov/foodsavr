import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../interfaces/i_auth_service.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/select_products_controller.dart';
import '../widgets/product/compact_location_card.dart';
import '../widgets/product/product_select_item.dart';

class SelectProductsView extends StatefulWidget {
  final String fromLocationId;
  final String toLocationId;

  const SelectProductsView({
    super.key,
    required this.fromLocationId,
    required this.toLocationId,
  });

  @override
  State<SelectProductsView> createState() => _SelectProductsViewState();
}

class _SelectProductsViewState extends State<SelectProductsView> {
  late final ProductService _productService;
  late final IAuthService _authService;
  late final SelectProductsController _controller;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _authService = getIt<IAuthService>();
    _controller = SelectProductsController();
    _searchController = TextEditingController();
    _productService
        .getProducts(_authService.getUserId())
        .then(_controller.loadProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Select Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Location display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CompactLocationCard(
                    label: 'From',
                    locationName: widget.fromLocationId,
                    isActive: true,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                Expanded(
                  child: CompactLocationCard(
                    label: 'To',
                    locationName: widget.toLocationId,
                    isActive: false,
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _controller.updateQuery,
              decoration: InputDecoration(
                hintText: 'Search your pantry...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'AVAILABLE STOCK',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final products = _controller.filteredProducts;
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductSelectItem(
                      product: product,
                      isSelected: _controller.isSelected(product.id),
                      onToggle: () => _controller.toggleSelection(product.id),
                    );
                  },
                );
              },
            ),
          ),

          // CTA
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: SafeArea(
                child: ElevatedButton(
                  onPressed: _controller.selectedCount > 0
                      ? () => context.pop()
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.swap_horiz),
                      const SizedBox(width: 8),
                      Text(
                        'Transfer ${_controller.selectedCount} items',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
