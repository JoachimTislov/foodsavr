import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../service_locator.dart';
import '../interfaces/i_auth_service.dart';
import '../widgets/common/navigation_card.dart';

class MainAppScreen extends StatelessWidget {
  const MainAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authService = getIt<IAuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodSavr'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            NavigationCard(
              title: 'My Inventory',
              description: 'View and manage your products',
              icon: Icons.inventory_2,
              color: colorScheme.primaryContainer,
              onTap: () {
                context.push('/product-list');
              },
            ),
            const SizedBox(height: 16),
            NavigationCard(
              title: 'Shopping List',
              description: 'Manage your shopping list',
              icon: Icons.shopping_cart,
              color: colorScheme.secondaryContainer,
              onTap: () {
                context.push('/collection-list');
              },
            ),
            const SizedBox(height: 16),
            NavigationCard(
              title: 'Global Products',
              description: 'Browse all available products',
              icon: Icons.public,
              color: colorScheme.tertiaryContainer,
              onTap: () {
                context.push('/global-products');
              },
            ),
          ],
        ),
      ),
    );
  }
}
