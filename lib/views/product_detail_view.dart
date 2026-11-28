import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart';

import 'product_form_view.dart';
import '../constants/adaptive_layout.dart';
import '../constants/product_categories.dart';
import '../controllers/preferences_controller.dart';
import '../models/product_model.dart';
import '../widgets/common/content_constraint.dart';
import '../widgets/expiry/add_expiry_sheet.dart';
import '../widgets/product/product_details_card.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../services/product_service.dart';
import '../interfaces/i_auth_service.dart';
import '../utils/user_error.dart';
import '../widgets/common/app_breadcrumbs.dart';

class ProductDetailView extends WatchingStatefulWidget {
  final Product product;

  /// When set, the view is embedded beside a list: it has no back button and
  /// calls this instead of popping once the product was deleted.
  final VoidCallback? onDeleted;

  const ProductDetailView({super.key, required this.product, this.onDeleted});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  late final CollectionService _collectionService;
  late final ProductService _productService;
  late final IAuthService _authService;
  List<String>? _inventoryNames;
  bool _isLoadingInventories = false;
  late Product _currentProduct;

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _productService = getIt<ProductService>();
    _authService = getIt<IAuthService>();
    _currentProduct = widget.product;
    _loadInventories();
  }

  Future<void> _loadInventories() async {
    final userId = _authService.getUserId();
    if (userId == null) return;

    setState(() => _isLoadingInventories = true);
    try {
      final inventories = await _collectionService.getInventoriesByProductId(
        userId,
        _currentProduct.id,
      );
      if (mounted) {
        setState(() {
          _inventoryNames = inventories.map((c) => c.name).toList();
          _isLoadingInventories = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Failed to load inventories: $e\n$stack');
      if (mounted) {
        setState(() => _isLoadingInventories = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'product.inventoryLoadError'.tr(namedArgs: {'error': '$e'}),
            ),
          ),
        );
      }
    }
  }

  Future<void> _edit() async {
    final result = await ProductFormView.show(
      context,
      product: _currentProduct,
    );
    if (result == true && mounted) await _refresh();
  }

  Future<void> _refresh() async {
    final updated = await _productService.getProductById(_currentProduct.id);
    if (updated == null || !mounted) return;
    setState(() => _currentProduct = updated);
    _loadInventories();
  }

  Future<void> _addExpiry() async {
    final input = await AddExpirySheet.show(context);
    if (input == null || !mounted) return;
    try {
      final updated = await _productService.addExpiry(
        _currentProduct.id,
        input.date,
        quantity: input.quantity,
      );
      if (!mounted) return;
      setState(() => _currentProduct = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('product.expiryAdded'.tr())));
    } catch (e, stack) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userErrorMessage(e, 'batchExpiry.saveError'.tr(), stack),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _currentProduct;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get status from product model
    final status = product.statusWithin(
      watchPropertyValue((PreferencesController c) => c.expiringSoonDays),
    );
    final statusColor = status.getColor(colorScheme);
    final statusMessage = status.getMessage();
    final statusIcon = status.getIcon();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading:
            widget.onDeleted == null && !AppBreadcrumbs.handlesBack(context),
      ),
      body: SingleChildScrollView(
        child: ContentConstraint(
          maxWidth: AdaptiveLayout.detailMaxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _edit,
                      child: ConstrainedBox(
                        // Keeps the tappable name at least a tap target tall.
                        constraints: const BoxConstraints(
                          minHeight: kMinInteractiveDimension,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: 1,
                          child: Text(
                            product.name,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (product.category != null)
                      Chip(
                        label: Text(ProductCategory.label(product.category!)),
                        labelStyle: theme.textTheme.labelLarge,
                        backgroundColor: colorScheme.secondaryContainer,
                        avatar: Icon(
                          ProductCategory.getIcon(product.category),
                          size: 20,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Status banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusMessage,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (product.daysUntilExpiration != null)
                                  Text(
                                    product.daysUntilExpiration! < 0
                                        ? 'product.expiredDaysAgo'.tr(
                                            namedArgs: {
                                              'days':
                                                  '${product.daysUntilExpiration!.abs()}',
                                            },
                                          )
                                        : 'product.daysRemaining'.tr(
                                            namedArgs: {
                                              'days':
                                                  '${product.daysUntilExpiration}',
                                            },
                                          ),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: statusColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _addExpiry,
                      icon: const Icon(Icons.event_available),
                      label: Text('product.addExpiry'.tr()),
                    ),
                    const SizedBox(height: 24),
                    // Description section
                    if (product.description.isNotEmpty) ...[
                      Text(
                        'product.description'.tr(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (_isLoadingInventories)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      )
                    else if (_inventoryNames != null &&
                        _inventoryNames!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'product.availableIn'.tr(
                                namedArgs: {
                                  'inventories': _inventoryNames!.join(', '),
                                },
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                    // Details section
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'product.details'.tr(),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'a11y.editProduct'.tr(),
                          onPressed: _edit,
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: colorScheme.error),
                          tooltip: 'a11y.deleteProduct'.tr(),
                          onPressed: () => _showDeleteConfirmation(product),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _edit,
                      child: ProductDetailsCard(product: product),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('product.delete'.tr()),
        content: Text(
          'product.deleteConfirmMessage'.tr(namedArgs: {'name': product.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await _productService.deleteProduct(product.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'product.deleted'.tr(namedArgs: {'name': product.name}),
                    ),
                  ),
                );
                final onDeleted = widget.onDeleted;
                if (onDeleted == null) {
                  context.pop(true);
                } else {
                  onDeleted();
                }
              } catch (e, stack) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      userErrorMessage(e, 'product.deleteError'.tr(), stack),
                    ),
                  ),
                );
              }
            },
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }
}
