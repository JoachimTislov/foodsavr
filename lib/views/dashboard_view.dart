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
import '../widgets/dashboard/expiring_item_card.dart';
import '../widgets/dashboard/overview_card.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  late final IAuthService _authService;
  late final ProductService _productService;
  late final CollectionService _collectionService;
  late final Future<List<Product>> _expiringSoonFuture;
  late final Future<List<Collection>> _inventoriesFuture;
  late final Future<List<Collection>> _shoppingListsFuture;

  @override
  void initState() {
    super.initState();
    _authService = getIt<IAuthService>();
    _productService = getIt<ProductService>();
    _collectionService = getIt<CollectionService>();
    final userId = _authService.getUserId();

    _expiringSoonFuture = _productService.getExpiringSoon(userId);

    _inventoriesFuture = _collectionService.getCollectionsForUser(
      userId!,
      type: CollectionType.inventory,
    );
    _shoppingListsFuture = _collectionService.getCollectionsForUser(
      userId,
      type: CollectionType.shoppingList,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final today = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'dashboard.title'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              today,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'common.settings'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
            tooltip: 'common.signOut'.tr(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExpiringSoonSection(expiringSoonFuture: _expiringSoonFuture),
            const SizedBox(height: 32),
            Text(
              'dashboard.overview'.tr(),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder(
              future: Future.wait([_inventoriesFuture, _shoppingListsFuture]),
              builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final inventories = snapshot.data?[0] as List<Collection>? ?? [];

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    OverviewCard(
                      title: 'dashboard.transfer'.tr(),
                      subtitle: 'dashboard.moveItems'.tr(),
                      icon: Icons.move_up,
                      iconColor: colorScheme.primary,
                      onTap: () => context.push('/transfer'),
                    ),
                    OverviewCard(
                      title: inventories.length == 1
                          ? 'dashboard.myInventory'.tr()
                          : 'dashboard.myInventories'.tr(),
                      subtitle: 'dashboard.manageProducts'.tr(),
                      icon: Icons.inventory_2_outlined,
                      iconColor: colorScheme.secondary,
                      onTap: () =>
                          context.push('/collection-list?type=inventory'),
                    ),
                    OverviewCard(
                      title: 'dashboard.shoppingList'.tr(),
                      subtitle: 'dashboard.manageLists'.tr(),
                      icon: Icons.shopping_cart_outlined,
                      iconColor: colorScheme.tertiary,
                      onTap: () =>
                          context.push('/collection-list?type=shopping'),
                    ),
                    OverviewCard(
                      title: 'dashboard.globalProducts'.tr(),
                      subtitle: 'dashboard.browseProducts'.tr(),
                      icon: Icons.public_outlined,
                      iconColor: colorScheme.primary,
                      onTap: () => context.push('/global-products'),
                    ),
                  ],
                );
              },
            ),
          ],
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
              onPressed: () => context.push('/product-list'),
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
                  ExpiringItemCard(product: products[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
