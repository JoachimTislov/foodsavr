import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/transfer/location_card.dart';
import '../widgets/transfer/location_section_header.dart';

/// A simple value object representing a storage location.
class _LocationOption {
  final String id;
  final String name;
  final String detail;
  final IconData icon;

  const _LocationOption({
    required this.id,
    required this.name,
    required this.detail,
    required this.icon,
  });
}

class TransferManagementView extends StatefulWidget {
  const TransferManagementView({super.key});

  @override
  State<TransferManagementView> createState() => _TransferManagementViewState();
}

class _TransferManagementViewState extends State<TransferManagementView> {
  // TODO(feat): replace with locations fetched from a LocationService when available
  static const List<_LocationOption> _fromOptions = [
    _LocationOption(
      id: 'main_fridge',
      name: 'Main Fridge',
      detail: 'Zone A • 42 Items',
      icon: Icons.kitchen,
    ),
    _LocationOption(
      id: 'pantry',
      name: 'Pantry',
      detail: 'Aisle 4 • 128 Items',
      icon: Icons.inventory_2_outlined,
    ),
    _LocationOption(
      id: 'deep_freezer',
      name: 'Deep Freezer',
      detail: 'Basement • 15 Items',
      icon: Icons.ac_unit,
    ),
  ];

  static const List<_LocationOption> _toOptions = [
    _LocationOption(
      id: 'garage',
      name: 'Garage',
      detail: 'Storage Rack 2',
      icon: Icons.garage,
    ),
    _LocationOption(
      id: 'loading_dock',
      name: 'Loading Dock',
      detail: 'Outbound Area',
      icon: Icons.local_shipping_outlined,
    ),
    _LocationOption(
      id: 'retail_shelf',
      name: 'Retail Shelf',
      detail: 'Main Floor',
      icon: Icons.storefront,
    ),
  ];

  String _selectedFromId = 'main_fridge';
  String _selectedToId = 'loading_dock';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  LocationSectionHeader(
                    icon: Icons.logout,
                    title: 'From Location',
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  for (final loc in _fromOptions) ...[
                    LocationCard(
                      title: loc.name,
                      subtitle: loc.detail,
                      icon: loc.icon,
                      isSelected: _selectedFromId == loc.id,
                      onTap: () => setState(() => _selectedFromId = loc.id),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                  LocationSectionHeader(
                    icon: Icons.login,
                    title: 'To Location',
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  for (final loc in _toOptions) ...[
                    LocationCard(
                      title: loc.name,
                      subtitle: loc.detail,
                      icon: loc.icon,
                      isSelected: _selectedToId == loc.id,
                      onTap: () => setState(() => _selectedToId = loc.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
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
                onPressed: () => context.push(
                  '/select-products',
                  extra: <String, String>{
                    'fromLocationId': _selectedFromId,
                    'toLocationId': _selectedToId,
                  },
                ),
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
}
