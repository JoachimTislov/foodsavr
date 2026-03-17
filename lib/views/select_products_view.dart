import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../interfaces/i_auth_service.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/select_products_controller.dart';
import '../widgets/product/compact_location_card.dart';
import '../widgets/product/product_select_item.dart';

class SelectProductsView extends WatchingStatefulWidget {
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

class _SelectProductsViewState extends State<SelectProductsView>
    with WatchItMixin {
  late final ProductService _productService;
  late final IAuthService _authService;
  late final SelectProductsController _controller;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _authService = getIt<IAuthService>();
    _controller = getIt<SelectProductsController>();
    _searchController = TextEditingController();

    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final userId = _authService.getUserId();
    if (userId == null) return;

    _controller.setLoading(true);
    // Note: getProductsInCollection was implemented as placeholder returning empty list
    // In a real app this would fetch the actual products.
    final products =
        await _productService.getProductsInCollection(widget.fromLocationId);
    if (mounted) {
      _controller.setAvailableProducts(products);
    }
  }

  @override
  Widget build(BuildContext context) {
    watch(_controller);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('transfer.select_products'.tr()),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: CompactLocationCard(
                        label: 'transfer.from'.tr(),
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
                        label: 'transfer.to'.tr(),
                        locationName: widget.toLocationId,
                        isActive: false,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'product.searchHint'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) => _controller.setSearchQuery(value),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _controller.filteredProducts.isEmpty
              ? Center(
                  child: Text(
                    'transfer.no_products_available'.tr(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _controller.filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _controller.filteredProducts[index];
                    return ProductSelectItem(
                      product: product,
                      isSelected: _controller.isSelected(product.id),
                      onToggle: () => _controller.toggleSelection(product.id),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _controller.selectedIds.isEmpty
                ? null
                : () {
                    Navigator.of(context).pop(_controller.selectedProducts);
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'transfer.confirm_selection'.tr(
                namedArgs: {'count': _controller.selectedIds.length.toString()},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
