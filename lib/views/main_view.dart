import 'package:flutter/material.dart';

import '../service_locator.dart';
import '../interfaces/auth_service_interface.dart';
import '../views/product_list_view.dart';
import '../views/collection_list_view.dart';

class MainAppScreen extends StatelessWidget {
  const MainAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
            _buildNavigationCard(
              context,
              title: 'My Inventory',
              description: 'View and manage your products',
              icon: Icons.inventory_2,
              color: colorScheme.primaryContainer,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ProductListView(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildNavigationCard(
              context,
              title: 'Collections',
              description: 'Browse standard collections',
              icon: Icons.folder,
              color: colorScheme.secondaryContainer,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CollectionListView(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: _getOnContainerColor(context, color),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getOnContainerColor(BuildContext context, Color containerColor) {
    final colorScheme = Theme.of(context).colorScheme;
    if (containerColor == colorScheme.primaryContainer) {
      return colorScheme.onPrimaryContainer;
    } else if (containerColor == colorScheme.secondaryContainer) {
      return colorScheme.onSecondaryContainer;
    } else if (containerColor == colorScheme.tertiaryContainer) {
      return colorScheme.onTertiaryContainer;
    }
    return colorScheme.onPrimaryContainer;
  }
}
