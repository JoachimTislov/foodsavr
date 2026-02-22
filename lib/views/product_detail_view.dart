import 'package:flutter/material.dart';
import '../constants/product_categories.dart';
import '../models/product_model.dart';
import '../widgets/product/product_details_card.dart';
import '../service_locator.dart';
import '../services/collection_service.dart';
import '../interfaces/i_auth_service.dart';

class ProductDetailView extends StatefulWidget {
  final Product product;

  const ProductDetailView({super.key, required this.product});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  late final CollectionService _collectionService;
  late final IAuthService _authService;
  List<String>? _inventoryNames;
  bool _isLoadingInventories = false;

  @override
  void initState() {
    super.initState();
    _collectionService = getIt<CollectionService>();
    _authService = getIt<IAuthService>();
    _loadInventories();
  }

  Future<void> _loadInventories() async {
    final userId = _authService.getUserId();
    if (userId == null) return;

    setState(() => _isLoadingInventories = true);
    try {
      final inventories = await _collectionService.getInventoriesByProductId(
        userId,
        widget.product.id,
      );
      if (mounted) {
        setState(() {
          _inventoryNames = inventories.map((c) => c.name).toList();
          _isLoadingInventories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingInventories = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Get status from product model
    final status = product.status;
    final statusColor = status.getColor(colorScheme);
    final statusMessage = status == ProductStatus.expired
        ? 'This product has expired'
        : 'This product expires soon';
    final statusIcon = status.getIcon();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit screen
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // TODO: Show delete confirmation
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image section
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Center(
                child: Icon(
                  ProductCategory.getIcon(product.category),
                  size: 100,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and category
                  Text(
                    product.name,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (product.category != null)
                    Chip(
                      label: Text(product.category!),
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
                                      ? 'Expired ${product.daysUntilExpiration!.abs()} days ago'
                                      : '${product.daysUntilExpiration} days remaining',
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
                  // Description section
                  Text(
                    'Description',
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
                            'Available in: ${_inventoryNames!.join(", ")}',
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
                  Text(
                    'Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProductDetailsCard(product: product),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
