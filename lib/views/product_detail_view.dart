import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:watch_it/watch_it.dart';

import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';
import '../constants/product_categories.dart';

class ProductDetailView extends WatchingWidget {
  final Product product;

  const ProductDetailView({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final collectionService = getIt<CollectionService>();
    final authService = getIt<IAuthService>();

    final inventoryNamesNotifier = createOnce(() => ValueNotifier<List<String>?>(null));
    final isLoadingInventoriesNotifier = createOnce(() => ValueNotifier<bool>(false));

    final inventoryNames = watch(inventoryNamesNotifier).value;
    final isLoadingInventories = watch(isLoadingInventoriesNotifier).value;

    Future<void> loadInventories() async {
      final userId = authService.getUserId();
      if (userId == null) return;

      isLoadingInventoriesNotifier.value = true;
      try {
        final collections = await collectionService.getCollectionsForUser(userId);
        final registries = collections.where((c) {
          return c.productIds.contains(product.id);
        }).toList();

        if (context.mounted) {
          inventoryNamesNotifier.value = registries.map((c) => c.name).toList();
        }
      } catch (e) {
        if (context.mounted) {
          inventoryNamesNotifier.value = [];
        }
      } finally {
        if (context.mounted) {
          isLoadingInventoriesNotifier.value = false;
        }
      }
    }

    callOnce((_) => loadInventories());

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
                product.category ?? ProductCategory.general,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Product Name
            Text(
              product.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (product.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                product.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 32),
            _buildSectionTitle(context, 'product.info'.tr()),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              Icons.qr_code_scanner,
              'product.id'.tr(),
              product.id.toString(),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle(context, 'product.storage'.tr()),
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
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
