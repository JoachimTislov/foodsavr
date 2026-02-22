import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TransferManagementView extends StatelessWidget {
  const TransferManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Transfer Inventory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel'),
          ),
        ],
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From Location
                  _buildLocationHeader(
                    context,
                    Icons.logout,
                    'From Location',
                    colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  _buildLocationCard(
                    context,
                    'Main Fridge',
                    'Zone A • 42 Items',
                    Icons.kitchen,
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildLocationCard(
                    context,
                    'Pantry',
                    'Aisle 4 • 128 Items',
                    Icons.inventory_2_outlined,
                    false,
                  ),
                  const SizedBox(height: 12),
                  _buildLocationCard(
                    context,
                    'Deep Freezer',
                    'Basement • 15 Items',
                    Icons.ac_unit,
                    false,
                  ),

                  // Flow Indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 40,
                            width: 1,
                            color: colorScheme.outlineVariant,
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_downward,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // To Location
                  _buildLocationHeader(
                    context,
                    Icons.login,
                    'To Location',
                    colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  _buildLocationCard(
                    context,
                    'Garage',
                    'Storage Rack 2',
                    Icons.garage,
                    false,
                  ),
                  const SizedBox(height: 12),
                  _buildLocationCard(
                    context,
                    'Loading Dock',
                    'Outbound Area',
                    Icons.local_shipping_outlined,
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildLocationCard(
                    context,
                    'Retail Shelf',
                    'Main Floor',
                    Icons.storefront,
                    false,
                  ),
                ],
              ),
            ),
          ),
          // CTA Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () => context.push('/select-products'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline),
                    SizedBox(width: 8),
                    Text(
                      'Select products',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationHeader(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildLocationCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        // Handle selection
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: colorScheme.primary)
              : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.1),
                ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected
                        ? colorScheme.onPrimary.withValues(alpha: 0.8)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
