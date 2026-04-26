import 'package:flutter/material.dart';

class DashboardActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const DashboardActionChip({
    super.key,
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
