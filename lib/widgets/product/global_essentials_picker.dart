import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../constants/product_categories.dart';
import '../../models/product_model.dart';
import '../../service_locator.dart';
import '../../services/product_service.dart';
import 'product_icon.dart';

/// Searchable, category-filterable picker for the global essentials catalog.
///
/// Supports both single-tap picking ([onSelect]) and multi-selection
/// ([selectedIds] + [onToggle]), with an optional [onQuickAdd] action per item.
class GlobalEssentialsPicker extends StatefulWidget {
  /// Preloaded essentials; when omitted, loads via [ProductService.getAllProducts].
  final List<Product>? products;

  /// Optional override for dependency injection in tests.
  final ProductService? productService;

  /// Called when an essential is tapped in single-pick mode.
  final ValueChanged<Product>? onSelect;

  /// Selected product IDs in multi-select mode.
  final Set<String>? selectedIds;

  /// Called when an essential is toggled in multi-select mode.
  final ValueChanged<Product>? onToggle;

  /// Optional one-tap quick-add action rendered on the trailing edge of each row.
  final ValueChanged<Product>? onQuickAdd;

  /// Whether to show the barcode badge on items that have one.
  final bool showBarcodeBadge;

  const GlobalEssentialsPicker({
    super.key,
    this.products,
    this.productService,
    this.onSelect,
    this.selectedIds,
    this.onToggle,
    this.onQuickAdd,
    this.showBarcodeBadge = true,
  });

  @override
  State<GlobalEssentialsPicker> createState() => _GlobalEssentialsPickerState();
}

class _GlobalEssentialsPickerState extends State<GlobalEssentialsPicker> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Product>> _productsFuture;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _productsFuture = _resolveProducts();
  }

  @override
  void didUpdateWidget(covariant GlobalEssentialsPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.products != oldWidget.products) {
      _productsFuture = _resolveProducts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Product>> _resolveProducts() {
    if (widget.products != null) {
      return Future.value(widget.products!);
    }
    final service = widget.productService ?? getIt<ProductService>();
    return service.getAllProducts();
  }

  List<Product> _filter(List<Product> items) {
    final query = _searchQuery.trim().toLowerCase();
    return [
      for (final product in items)
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'product.essentials.searchHint'.tr(),
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
        Expanded(
          child: FutureBuilder<List<Product>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'common.error_loading_data'.tr(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                );
              }
              final filtered = _filter(snapshot.data ?? const []);
              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_outlined,
                          size: 40,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'product.essentials.empty'.tr(),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  final isSelected =
                      widget.selectedIds?.contains(product.id) ?? false;
                  return _EssentialListTile(
                    product: product,
                    isSelected: isSelected,
                    multiSelect: widget.selectedIds != null,
                    showBarcodeBadge: widget.showBarcodeBadge,
                    onTap: () {
                      if (widget.onToggle != null) {
                        widget.onToggle!(product);
                      } else {
                        widget.onSelect?.call(product);
                      }
                    },
                    onQuickAdd: widget.onQuickAdd == null
                        ? null
                        : () => widget.onQuickAdd!(product),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EssentialListTile extends StatelessWidget {
  final Product product;
  final bool isSelected;
  final bool multiSelect;
  final bool showBarcodeBadge;
  final VoidCallback onTap;
  final VoidCallback? onQuickAdd;

  const _EssentialListTile({
    required this.product,
    required this.isSelected,
    required this.multiSelect,
    required this.showBarcodeBadge,
    required this.onTap,
    this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasBarcode =
        showBarcodeBadge &&
        product.barcode != null &&
        product.barcode!.trim().isNotEmpty;

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
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (product.category != null)
            Text(
              ProductCategory.label(product.category!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          if (hasBarcode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.qr_code_2,
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    product.barcode!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: multiSelect
          ? ExcludeSemantics(
              child: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            )
          : onQuickAdd != null
          ? IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'product.essentials.quickAdd'.tr(),
              onPressed: onQuickAdd,
            )
          : null,
    );
  }
}
