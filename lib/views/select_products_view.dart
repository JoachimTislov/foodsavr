import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../interfaces/i_auth_service.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/select_products_controller.dart';
import '../widgets/product/compact_location_card.dart';
import '../widgets/product/product_select_item.dart';

class SelectProductsView extends WatchingWidget {
  final String fromLocationId;
  final String toLocationId;

  const SelectProductsView({
    super.key,
    required this.fromLocationId,
    required this.toLocationId,
  });

  @override
  Widget build(BuildContext context) {
    final productService = getIt<ProductService>();
    final authService = getIt<IAuthService>();
    final controller = watchIt<SelectProductsController>();
    final searchController = createOnce(() => TextEditingController());

    Future<void> loadProducts() async {
      final userId = authService.getUserId();
      if (userId == null) return;

      controller.setLoading(true);
      final products = await productService.getProductsInCollection(fromLocationId);
      if (context.mounted) {
        controller.setAvailableProducts(products);
      }
    }

    callOnce((_) => loadProducts());

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
                        locationName: fromLocationId,
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
                        locationName: toLocationId,
                        isActive: false,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'product.searchHint'.tr(),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) => controller.setSearchQuery(value),
                ),
              ),
            ],
          ),
        ),
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.filteredProducts.isEmpty
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
                  itemCount: controller.filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = controller.filteredProducts[index];
                    return ProductSelectItem(
                      product: product,
                      isSelected: controller.isSelected(product.id),
                      onToggle: () => controller.toggleSelection(product.id),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: controller.selectedIds.isEmpty
                ? null
                : () {
                    Navigator.of(context).pop(controller.selectedProducts);
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'transfer.confirm_selection'.tr(
                namedArgs: {'count': controller.selectedIds.length.toString()},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
