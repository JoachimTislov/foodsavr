import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SelectProductsView extends StatefulWidget {
  const SelectProductsView({super.key});

  @override
  State<SelectProductsView> createState() => _SelectProductsViewState();
}

class _SelectProductsViewState extends State<SelectProductsView> {
  final List<Map<String, dynamic>> _products = [
    {
      'name': 'Whole Wheat Bread',
      'stock': 'Low (2 units)',
      'color': Colors.orange,
      'selected': true,
    },
    {
      'name': 'Almond Milk',
      'stock': 'Medium (5 units)',
      'color': Colors.green,
      'selected': false,
    },
    {
      'name': 'Greek Yogurt',
      'stock': 'Out of Stock (0 units)',
      'color': Colors.red,
      'selected': false,
    },
    {
      'name': 'Organic Eggs',
      'stock': 'Good (12 units)',
      'color': Colors.green,
      'selected': false,
    },
    {
      'name': 'Apples',
      'stock': 'Good (10 units)',
      'color': Colors.green,
      'selected': false,
    },
    {
      'name': 'Chicken Breast',
      'stock': 'Low (1 unit)',
      'color': Colors.orange,
      'selected': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Select Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Location Selection (Compact)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCompactLocationCard(
                    context,
                    'From',
                    'Main Fridge',
                    true,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                Expanded(
                  child: _buildCompactLocationCard(
                    context,
                    'To',
                    'Loading Dock',
                    false,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search your pantry...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Product List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'AVAILABLE STOCK',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Product List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _products.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final product = _products[index];
                return _buildProductListItem(context, index, product);
              },
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
                onPressed: () {
                  // Perform transfer logic
                  context.pop(); // Go back to transfer management
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.swap_horiz),
                    const SizedBox(width: 8),
                    Text(
                      'Transfer ${_products.where((p) => p['selected'] as bool).length} items',
                      style: const TextStyle(
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

  Widget _buildCompactLocationCard(
    BuildContext context,
    String label,
    String locationName,
    bool isActive,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Blue bar indicator
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: isActive ? colorScheme.primary : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      locationName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListItem(
    BuildContext context,
    int index,
    Map<String, dynamic> product,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () {
        setState(() {
          _products[index]['selected'] =
              !(_products[index]['selected'] as bool);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (product['selected'] as bool)
                ? colorScheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: product['selected'] as bool,
                onChanged: (value) {
                  setState(() {
                    _products[index]['selected'] = value ?? false;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] as String,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: product['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Stock level: ',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        product['stock'] as String,
                        style: textTheme.bodySmall?.copyWith(
                          color: product['color'] as Color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Icons on the right omitted per instruction
          ],
        ),
      ),
    );
  }
}
