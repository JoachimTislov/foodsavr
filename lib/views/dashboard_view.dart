import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../interfaces/i_auth_service.dart';
import '../models/product_model.dart';
import '../models/collection_model.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
import '../services/collection_service.dart';
import '../utils/collection_types.dart'; // Import CollectionType
import '../utils/product_add_helper.dart';
import '../views/product_detail_view.dart';
import '../widgets/common/app_refresh_indicator.dart';
import '../widgets/dashboard/expiring_item_card.dart';
import '../widgets/dashboard/overview_card.dart';
import 'collection_form_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late final IAuthService _authService;
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late Future<List<Product>> _expiringSoonFuture;
  late Future<List<Collection>> _inventoriesFuture;

  @override
  void initState() {
    super.initState();
    _authService = getIt<IAuthService>();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    final userId = _authService.getUserId();

    if (userId == null) {
      _expiringSoonFuture = Future.value([]);
      _inventoriesFuture = Future.value([]);
      return;
    }

    _expiringSoonFuture = _productService.getExpiringSoon(userId);
    _inventoriesFuture = _collectionService.getCollectionsForUser(
      userId,
      type: CollectionType.inventory,
    );
  }

  Future<void> _refreshDashboard() async {
    final userId = _authService.getUserId();
    if (userId == null) return;

    setState(() {
      _expiringSoonFuture = _productService.getExpiringSoon(userId);
      _inventoriesFuture = _collectionService.getCollectionsForUser(
        userId,
        type: CollectionType.inventory,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final today = DateFormat.yMMMMEEEEd(
      context.locale.toString(),
    ).format(DateTime.now());

    return Scaffold(
      body: AppRefreshIndicator(
        onRefresh: _refreshDashboard,
        isScrollable: true,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: 24,
            top: MediaQuery.of(context).padding.top + 24,
            right: 24,
            bottom: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'dashboard.title'.tr(),
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        today,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _ExpiringSoonSection(expiringSoonFuture: _expiringSoonFuture),
              const SizedBox(height: 24),
              Text(
                'dashboard.overview'.tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Collection>>(
                future: _inventoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text('dashboard.errorLoading'.tr());
                  }

                  final inventories = snapshot.data ?? [];

                  final cards = <Widget>[
                    OverviewCard(
                      title: 'product.all_products'.tr(),
                      subtitle: 'dashboard.browseProducts'.tr(),
                      icon: Icons.inventory_outlined,
                      iconColor: colorScheme.primary,
                      onTap: () => context.go('/dashboard/product-list'),
                    ),
                    if (inventories.length > 1)
                      OverviewCard(
                        title: 'dashboard.transfer'.tr(),
                        subtitle: 'dashboard.moveItems'.tr(),
                        icon: Icons.move_up,
                        iconColor: colorScheme.primary,
                        onTap: () => context.go('/transfer'),
                      ),
                    OverviewCard(
                      title: 'dashboard.globalProducts'.tr(),
                      subtitle: 'dashboard.browseProducts'.tr(),
                      icon: Icons.public_outlined,
                      iconColor: colorScheme.primary,
                      onTap: () => context.go('/dashboard/global-products'),
                    ),
                  ];

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: cards,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'dashboard.actions'.tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ActionChip(
                    icon: Icons.add_box_outlined,
                    label: 'dashboard.createProduct'.tr(),
                    color: colorScheme.primary,
                    onTap: () => ProductAddHelper.startAddProductFlow(context),
                  ),
                  const SizedBox(width: 8),
                  _ActionChip(
                    icon: Icons.shopping_cart_outlined,
                    label: 'dashboard.createShoppingList'.tr(),
                    color: colorScheme.secondary,
                    onTap: () => CollectionFormView.show(
                      context,
                      type: CollectionType.shoppingList,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpiringSoonSection extends StatelessWidget {
  final Future<List<Product>> expiringSoonFuture;

  const _ExpiringSoonSection({required this.expiringSoonFuture});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'dashboard.expiringSoon'.tr(),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/dashboard/product-list'),
              child: Text('common.viewAll'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Product>>(
          future: expiringSoonFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return Text(
                'dashboard.noProductsExpiringSoon'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: [
                for (int i = 0; i < products.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  ExpiringItemCard(
                    product: products[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailView(product: products[i]),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipColor = color ?? colorScheme.primary;

    return Expanded(
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          backgroundColor: chipColor.withValues(alpha: 0.1),
          foregroundColor: chipColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
