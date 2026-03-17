import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart';

import '../models/product_model.dart';
import '../widgets/product/product_select_item.dart';

class _LocationOption {
  final String id;
  final String name;
  final IconData icon;

  const _LocationOption({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class TransferManagementView extends WatchingWidget {
  const TransferManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO(feat): replace with locations fetched from a LocationService when available
    const List<_LocationOption> fromOptions = [
      _LocationOption(
        id: 'main_fridge',
        name: 'Main Fridge',
        icon: Icons.kitchen,
      ),
      _LocationOption(id: 'pantry', name: 'Pantry', icon: Icons.shelves),
    ];

    const List<_LocationOption> toOptions = [
      _LocationOption(
        id: 'main_fridge',
        name: 'Main Fridge',
        icon: Icons.kitchen,
      ),
      _LocationOption(id: 'pantry', name: 'Pantry', icon: Icons.shelves),
      _LocationOption(id: 'freezer', name: 'Freezer', icon: Icons.ac_unit),
    ];

    final fromLocation = createOnce(
      () => ValueNotifier<_LocationOption?>(null),
    );
    final toLocation = createOnce(() => ValueNotifier<_LocationOption?>(null));
    final selectedProducts = createOnce(() => ValueNotifier<List<Product>>([]));
    final isTransferring = createOnce(() => ValueNotifier<bool>(false));

    final from = watch(fromLocation).value;
    final to = watch(toLocation).value;
    final products = watch(selectedProducts).value;
    final transferring = watch(isTransferring).value;

    Future<void> pickProducts() async {
      if (from == null || to == null) return;

      final result = await context.push<List<Product>>(
        '/transfer/select?from=${from.id}&to=${to.id}',
      );

      if (result != null && context.mounted) {
        selectedProducts.value = result;
      }
    }

    Future<void> performTransfer() async {
      if (from == null || to == null || products.isEmpty) return;

      isTransferring.value = true;
      try {
        // TODO(feat): Implement actual transfer logic in a service
        await Future.delayed(const Duration(seconds: 1));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'transfer.success_message'.tr(
                  namedArgs: {'count': products.length.toString()},
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('common.error_loading_data'.tr())),
          );
        }
      } finally {
        if (context.mounted) isTransferring.value = false;
      }
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('transfer.title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'transfer.configure_transfer'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // From Location
            _buildLocationPicker(
              context,
              label: 'transfer.from'.tr(),
              selected: from,
              options: fromOptions,
              onChanged: (val) {
                fromLocation.value = val;
                selectedProducts.value = [];
              },
            ),

            const SizedBox(height: 16),
            const Center(child: Icon(Icons.arrow_downward, size: 24)),
            const SizedBox(height: 16),

            // To Location
            _buildLocationPicker(
              context,
              label: 'transfer.to'.tr(),
              selected: to,
              options: toOptions,
              onChanged: (val) {
                toLocation.value = val;
                if (val?.id == from?.id) {
                  fromLocation.value = null;
                  selectedProducts.value = [];
                }
              },
            ),

            const SizedBox(height: 40),

            // Product Selection Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'transfer.products_to_transfer'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: from != null && to != null ? pickProducts : null,
                  icon: const Icon(Icons.add),
                  label: Text('common.select'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (products.isEmpty)
              _buildEmptyProductsState(context)
            else
              _buildSelectedProductsList(context, products, selectedProducts),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FilledButton(
            onPressed:
                from != null &&
                    to != null &&
                    products.isNotEmpty &&
                    !transferring
                ? performTransfer
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: transferring
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('transfer.start_transfer'.tr()),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPicker(
    BuildContext context, {
    required String label,
    required _LocationOption? selected,
    required List<_LocationOption> options,
    required ValueChanged<_LocationOption?> onChanged,
  }) {
    return DropdownButtonFormField<_LocationOption>(
      initialValue: selected,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(selected?.icon ?? Icons.location_on_outlined),
      ),
      items: options.map((opt) {
        return DropdownMenuItem(value: opt, child: Text(opt.name));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildEmptyProductsState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'transfer.no_products_selected'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedProductsList(
    BuildContext context,
    List<Product> products,
    ValueNotifier<List<Product>> notifier,
  ) {
    return Column(
      children: products.map((p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ProductSelectItem(
            product: p,
            isSelected: true,
            onToggle: () {
              final newList = List<Product>.from(notifier.value);
              newList.removeWhere((item) => item.id == p.id);
              notifier.value = newList;
            },
          ),
        );
      }).toList(),
    );
  }
}
