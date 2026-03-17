import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../interfaces/i_auth_service.dart';

class ProductDetailView extends StatefulWidget with WatchItStatefulWidgetMixin {
  final Product product;

  const ProductDetailView({super.key, required this.product});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView>
    with WatchItMixin {
  late final CollectionService _collectionService;
  late final ProductService _productService;
  late final IAuthService _authService;
  final _inventoryNames = ValueNotifier<List<String>?>(null);
  final _isLoadingInventories = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _productService = getIt<ProductService>();
    _authService = getIt<IAuthService>();
    _loadInventories();
  }

  @override
  void dispose() {
    _inventoryNames.dispose();
    _isLoadingInventories.dispose();
    super.dispose();
  }

  Future<void> _loadInventories() async {
    final userId = _authService.getUserId();
    if (userId == null) return;

    _isLoadingInventories.value = true;
    try {
      final collections = await _collectionService.getCollectionsForUser(userId);
      final registries = collections.where((c) {
        return c.productIds.contains(widget.product.id);
      }).toList();

      if (mounted) {
        _inventoryNames.value = registries.map((c) => c.name).toList();
      }
    } catch (e) {
      if (mounted) {
        _inventoryNames.value = [];
      }
    } finally {
      if (mounted) {
        _isLoadingInventories.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventoryNames = watch(_inventoryNames).value;
    final isLoadingInventories = watch(_isLoadingInventories).value;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('product.details'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO(feat): Implement product edit
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Category Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.product.category ?? '',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Product Name
            Text(
              widget.product.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.product.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.product.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 32),
            _buildSectionTitle('product.info'.tr()),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.qr_code_scanner,
              'product.id'.tr(),
              widget.product.id.toString(),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('product.storage'.tr()),
            const SizedBox(height: 16),
            if (isLoadingInventories)
              const Center(child: CircularProgressIndicator())
            else if (inventoryNames == null || inventoryNames.isEmpty)
              Text(
                'product.noInventoriesFound'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: inventoryNames.map((name) {
                  return Chip(
                    label: Text(name),
                    avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
