import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../constants/product_categories.dart';
import '../interfaces/i_auth_service.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../widgets/common/adaptive_sheet.dart';
import '../widgets/product/product_icon.dart';

enum _ProductSourceFilter { all, personal, essentials }

/// Displays user's personal products and global essentials for adding to a
/// collection in 1-2 taps.
class AddProductToCollectionView extends StatelessWidget {
  final String collectionId;

  const AddProductToCollectionView({super.key, required this.collectionId});

  /// Shows the product picker as an adaptive sheet/dialog.
  /// Returns `true` if products were added.
  static Future<bool?> show(BuildContext context, String collectionId) {
    return AdaptiveSheet.show<bool>(
      context,
      builder: (_) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: _AddProductSheet(collectionId: collectionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This widget exists only for its static show() method.
    return const SizedBox.shrink();
  }
}

class _LoadedRegistry {
  final List<Product> personal;
  final List<Product> essentials;

  const _LoadedRegistry({required this.personal, required this.essentials});

  List<Product> get all => [...personal, ...essentials];
}

class _AddProductSheet extends StatefulWidget {
  final String collectionId;

  const _AddProductSheet({required this.collectionId});

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final IAuthService _authService;
  late Future<_LoadedRegistry> _registryFuture;

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  String? _selectedCategory;
  _ProductSourceFilter _sourceFilter = _ProductSourceFilter.all;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _registryFuture = _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_LoadedRegistry> _loadProducts() async {
    final userId = _authService.getUserId();
    final results = await Future.wait([
      _productService.getPersonalProducts(userId),
      _productService.getAllProducts(),
    ]);
    return _LoadedRegistry(personal: results[0], essentials: results[1]);
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _searchQuery.trim().toLowerCase();
    return [
      for (final product in products)
        if (_matchesCategory(product) && _matchesQuery(product, query)) product,
    ];
  }

  bool _matchesCategory(Product product) {
    if (_selectedCategory == null) return true;
    return ProductCategory.normalize(product.category) == _selectedCategory;
  }

  bool _matchesQuery(Product product, String query) {
    if (query.isEmpty) return true;
    if (product.name.toLowerCase().contains(query)) return true;
    if (product.description.toLowerCase().contains(query)) return true;
    final barcode = product.barcode;
    if (barcode != null && barcode.toLowerCase().contains(query)) return true;
    final category = product.category;
    if (category != null &&
        ProductCategory.label(category).toLowerCase().contains(query)) {
      return true;
    }
    return false;
  }

  void _toggleSelection(String productId) {
    setState(() {
      if (_selectedIds.contains(productId)) {
        _selectedIds.remove(productId);
      } else {
        _selectedIds.add(productId);
      }
    });
  }

  Future<void> _addSelected() async {
    if (_selectedIds.isEmpty) return;
    final userId = _authService.getUserId();
    if (userId == null) return;
    setState(() => _isSaving = true);
    try {
      final registry = await _registryFuture;
      final selectedProducts = registry.all
          .where((product) => _selectedIds.contains(product.id))
          .toList();
      final createdProductIds = <String>[];
      for (final sourceProduct in selectedProducts) {
        final currentProduct = Product(
          id: '',
          name: sourceProduct.name,
          description: sourceProduct.description,
          userId: userId,
          nonExpiringQuantity: 1,
          category: sourceProduct.category,
          barcode: sourceProduct.barcode,
          imageUrl: sourceProduct.imageUrl,
          tags: sourceProduct.tags,
          registryType: 'current',
          mappedFromProductId: sourceProduct.id,
        );
        final savedProduct = await _productService.addProduct(currentProduct);
        createdProductIds.add(savedProduct.id);
      }
      await _collectionService.addProductsToCollection(
        widget.collectionId,
        createdProductIds,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error_loading_data'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'product.select'.tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'common.close'.tr(),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'listQuery.search'.tr(),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'a11y.clearSearch'.tr(),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 8),
        SegmentedButton<_ProductSourceFilter>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: _ProductSourceFilter.all,
              label: Text('product.essentials.allSources'.tr()),
            ),
            ButtonSegment(
              value: _ProductSourceFilter.personal,
              label: Text('product.essentials.yourProducts'.tr()),
            ),
            ButtonSegment(
              value: _ProductSourceFilter.essentials,
              label: Text('product.essentials.title'.tr()),
            ),
          ],
          selected: {_sourceFilter},
          onSelectionChanged: (selection) =>
              setState(() => _sourceFilter = selection.first),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('listQuery.anyCategory'.tr()),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
              ),
              for (final categoryKey in ProductCategory.allKeys)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(ProductCategory.label(categoryKey)),
                    selected: _selectedCategory == categoryKey,
                    onSelected: (selected) => setState(
                      () => _selectedCategory = selected ? categoryKey : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<_LoadedRegistry>(
            future: _registryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('common.error_loading_data'.tr()));
              }
              final registry =
                  snapshot.data ??
                  const _LoadedRegistry(personal: [], essentials: []);
              final showPersonal =
                  _sourceFilter != _ProductSourceFilter.essentials;
              final showEssentials =
                  _sourceFilter != _ProductSourceFilter.personal;
              final personal = showPersonal
                  ? _filterProducts(registry.personal)
                  : const <Product>[];
              final essentials = showEssentials
                  ? _filterProducts(registry.essentials)
                  : const <Product>[];

              if (personal.isEmpty && essentials.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          registry.all.isEmpty
                              ? 'product.noProductsFound'.tr()
                              : 'listQuery.noMatches'.tr(),
                          style: textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        if (registry.all.isEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'product.addFirst'.tr(),
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (personal.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'product.essentials.yourProducts'.tr(),
                      count: personal.length,
                    ),
                    for (final product in personal)
                      _SelectableProductTile(
                        product: product,
                        isSelected: _selectedIds.contains(product.id),
                        onTap: () => _toggleSelection(product.id),
                      ),
                  ],
                  if (essentials.isNotEmpty) ...[
                    if (personal.isNotEmpty) const SizedBox(height: 8),
                    _SectionHeader(
                      title: 'product.essentials.title'.tr(),
                      count: essentials.length,
                    ),
                    for (final product in essentials)
                      _SelectableProductTile(
                        product: product,
                        isSelected: _selectedIds.contains(product.id),
                        onTap: () => _toggleSelection(product.id),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: FilledButton(
            onPressed: _selectedIds.isEmpty || _isSaving ? null : _addSelected,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _selectedIds.isEmpty
                        ? 'common.add'.tr()
                        : 'product.essentials.addSelected'.plural(
                            _selectedIds.length,
                            name: 'count',
                          ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableProductTile extends StatelessWidget {
  final Product product;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableProductTile({
    required this.product,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onTap,
      leading: ProductIcon.fromProduct(product, size: 40),
      title: Text(
        product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: product.category != null
          ? Text(
              ProductCategory.label(product.category!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: ExcludeSemantics(
        child: Icon(
          isSelected ? Icons.check_circle : Icons.circle_outlined,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
