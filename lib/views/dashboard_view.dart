import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../interfaces/i_auth_service.dart';
import '../models/product_model.dart';
import '../service_locator.dart';
import '../services/product_service.dart';
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
  late final Future<List<Product>> _expiringSoonFuture;

  @override
  void initState() {
    super.initState();
    _authService = getIt<IAuthService>();
    _productService = getIt<ProductService>();
    _expiringSoonFuture = _productService.getExpiringSoon(
      _authService.getUserId(),
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
            const Text(
              'Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold),
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
            onPressed: () {},
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
            tooltip: 'Sign Out',
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
              'Overview',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                OverviewCard(
                  title: 'Transfer',
                  subtitle: 'Move items',
                  icon: Icons.move_up,
                  iconColor: colorScheme.primary,
                  onTap: () => context.push('/transfer'),
                ),
                OverviewCard(
                  title: 'My Inventory',
                  subtitle: 'Manage products',
                  icon: Icons.inventory_2_outlined,
                  iconColor: colorScheme.secondary,
                  onTap: () => context.push('/product-list'),
                ),
                OverviewCard(
                  title: 'Shopping List',
                  subtitle: 'Manage lists',
                  icon: Icons.shopping_cart_outlined,
                  iconColor: colorScheme.tertiary,
                  onTap: () => context.push('/collection-list'),
                ),
                OverviewCard(
                  title: 'Global Products',
                  subtitle: 'Browse products',
                  icon: Icons.public_outlined,
                  iconColor: colorScheme.primary,
                  onTap: () => context.push('/global-products'),
                ),
              ],
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
              'Expiring Soon',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/product-list'),
              child: const Text('View All'),
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
                'No products expiring soon.',
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
