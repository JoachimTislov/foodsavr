import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../utils/view_mode_helper.dart';

class ViewModeToggle extends StatelessWidget {
  final ProductViewMode viewMode;
  final ValueChanged<ProductViewMode> onModeChanged;

  const ViewModeToggle({
    super.key,
    required this.viewMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<ProductViewMode>(
      icon: Icon(
        ViewModeHelper.getViewModeIcon(viewMode),
        color: colorScheme.primary,
      ),
      onSelected: onModeChanged,
      itemBuilder: (context) => [
        _buildMenuItem(
          ProductViewMode.compact,
          Icons.view_headline,
          'product.compact'.tr(),
          colorScheme,
        ),
        _buildMenuItem(
          ProductViewMode.normal,
          Icons.view_agenda,
          'product.normal'.tr(),
          colorScheme,
        ),
        _buildMenuItem(
          ProductViewMode.details,
          Icons.view_day,
          'product.details'.tr(),
          colorScheme,
        ),
      ],
    );
  }

  PopupMenuItem<ProductViewMode> _buildMenuItem(
    ProductViewMode mode,
    IconData icon,
    String label,
    ColorScheme colorScheme,
  ) {
    final isSelected = viewMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? colorScheme.primary : null),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
