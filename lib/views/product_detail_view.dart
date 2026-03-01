import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get_it/get_it.dart';
import '../../models/product_model.dart';
import '../../interfaces/i_auth_service.dart';
import '../../services/collection_service.dart';
import '../../widgets/product/product_details_card.dart';

class ProductDetailView extends StatefulWidget {
  final Product product;

  const ProductDetailView({super.key, required this.product});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  final _collectionService = GetIt.I<CollectionService>();
  final _authService = GetIt.I<IAuthService>();
  List<String>? _inventoryNames;
  bool _isLoadingInventories = true;

  @override
  void initState() {
    super.initState();
    _loadInventories();
  }

  Future<void> _loadInventories() async {
    try {
      final userId = _authService.getUserId();
      if (userId == null) return;

      final inventories = await _collectionService.getInventoriesByProductId(
        userId,
        widget.product.id,
      );

      if (mounted) {
        setState(() {
          _inventoryNames = inventories.map((i) => i.name).toList();
          _isLoadingInventories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInventories = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = product.status;
    final statusColor = status.getColor(colorScheme);
    final statusIcon = status.getIcon();
    final statusMessage = status.getMessage();

    return Scaffold(
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(product.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('product.editSoon'.tr())),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('product.delete'.tr())),
                    );
                  },
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),
                  // Expiration Highlight
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
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
                                      ? 'product.status_expired_days_ago'.tr(
                                          args: [
                                            product.daysUntilExpiration!
                                                .abs()
                                                .toString(),
                                          ],
                                        )
                                      : 'product.status_days_remaining'.tr(
                                          args: [
                                            product.daysUntilExpiration
                                                .toString(),
                                          ],
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
                  // Description section
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
                  Text(
                    'product.details_section'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProductDetailsCard(product: product),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
