import 'package:flutter/material.dart';

/// The circular leading icon of a settings row.
class SettingsIcon extends StatelessWidget {
  final IconData icon;
  final bool isDestructive;

  const SettingsIcon(this.icon, {super.key, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDestructive
            ? colorScheme.errorContainer.withValues(alpha: 0.7)
            : colorScheme.primaryContainer.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color: isDestructive ? colorScheme.error : colorScheme.primary,
      ),
    );
  }
}
