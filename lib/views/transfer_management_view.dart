import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart';

import '../interfaces/i_auth_service.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
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

class TransferManagementView extends WatchingStatefulWidget {
  const TransferManagementView({super.key});

  @override
  State<TransferManagementView> createState() => _TransferManagementViewState();
}

class _TransferManagementViewState extends State<TransferManagementView>
    with WatchItMixin {
  // TODO(feat): replace with locations fetched from a LocationService when available
  static const List<_LocationOption> _fromOptions = [
    _LocationOption(
      id: 'main_fridge',
      name: 'Main Fridge',
      icon: Icons.kitchen,
    ),
    _LocationOption(
      id: 'pantry',
      name: 'Pantry',
      icon: Icons.shelves,
    ),
  ];

  static const List<_LocationOption> _toOptions = [
    _LocationOption(
      id: 'main_fridge',
      name: 'Main Fridge',
      icon: Icons.kitchen,
    ),
    _LocationOption(
      id: 'pantry',
      name: 'Pantry',
      icon: Icons.shelves,
    ),
    _LocationOption(
      id: 'freezer',
      name: 'Freezer',
      icon: Icons.ac_unit,
    ),
  ];

  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final IAuthService _authService;

  final _fromLocation = ValueNotifier<_LocationOption?>(null);
  final _toLocation = ValueNotifier<_LocationOption?>(null);
  final _selectedProducts = ValueNotifier<List<Product>>([]);
  final _isTransferring = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
  }

  @override
  void dispose() {
    _fromLocation.dispose();
    _toLocation.dispose();
    _selectedProducts.dispose();
    _isTransferring.dispose();
    super.dispose();
  }

  Future<void> _pickProducts() async {
    final from = _fromLocation.value;
    final to = _toLocation.value;
    if (from == null || to == null) return;

    final result = await context.push<List<Product>>(
      '/transfer/select?from=${from.id}&to=${to.id}',
    );

    if (result != null && mounted) {
      _selectedProducts.value = result;
    }
  }

  Future<void> _performTransfer() async {
    final from = _fromLocation.value;
    final to = _toLocation.value;
    final products = _selectedProducts.value;

    if (from == null || to == null || products.isEmpty) return;

    _isTransferring.value = true;
    try {
      // TODO(feat): Implement actual transfer logic in a service
      // This would involve updating registry mapping or moving between physical locations
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('transfer.success_message'.tr(
              namedArgs: {'count': products.length.toString()},
            )),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error_loading_data'.tr())),
        );
      }
    } finally {
      if (mounted) _isTransferring.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = watch(_fromLocation).value;
    final to = watch(_toLocation).value;
    final products = watch(_selectedProducts).value;
    final transferring = watch(_isTransferring).value;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('transfer.title'.tr()),
      ),
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
              label: 'transfer.from'.tr(),
              selected: from,
              options: _fromOptions,
              onChanged: (val) {
                _fromLocation.value = val;
                _selectedProducts.value = [];
              },
            ),

            const SizedBox(height: 16),
            const Center(child: Icon(Icons.arrow_downward, size: 24)),
            const SizedBox(height: 16),

            // To Location
            _buildLocationPicker(
              label: 'transfer.to'.tr(),
              selected: to,
              options: _toOptions,
              onChanged: (val) {
                _toLocation.value = val;
                // Don't reset products if only 'to' changed,
                // but usually we want to ensure from != to
                if (val?.id == from?.id) {
                  _fromLocation.value = null;
                  _selectedProducts.value = [];
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
                  onPressed: from != null && to != null ? _pickProducts : null,
                  icon: const Icon(Icons.add),
                  label: Text('common.select'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (products.isEmpty)
              _buildEmptyProductsState()
            else
              _buildSelectedProductsList(products),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FilledButton(
            onPressed: from != null &&
                    to != null &&
                    products.isNotEmpty &&
                    !transferring
                ? _performTransfer
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

  Widget _buildLocationPicker({
    required String label,
    required _LocationOption? selected,
    required List<_LocationOption> options,
    required ValueChanged<_LocationOption?> onChanged,
  }) {
    return DropdownButtonFormField<_LocationOption>(
      value: selected,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: Icon(selected?.icon ?? Icons.location_on_outlined),
      ),
      items: options.map((opt) {
        return DropdownMenuItem(
          value: opt,
          child: Text(opt.name),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildEmptyProductsState() {
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
          Icon(Icons.inventory_2_outlined,
              size: 48, color: colorScheme.outline),
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

  Widget _buildSelectedProductsList(List<Product> products) {
    return Column(
      children: products.map((p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ProductSelectItem(
            product: p,
            isSelected: true,
            onToggle: () {
              final newList = List<Product>.from(_selectedProducts.value);
              newList.removeWhere((item) => item.id == p.id);
              _selectedProducts.value = newList;
            },
          ),
        );
      }).toList(),
    );
  }
}
