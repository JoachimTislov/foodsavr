import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';

/// One entry point in the dashboard quick actions. A null [onTap] renders it
/// disabled; [disabledReason] then says why, as a subtitle and a [tooltip].
class DashboardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? disabledReason;
  final String? tooltip;

  /// Renders the filled style, for the main action.
  final bool primary;

  const DashboardActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.disabledReason,
    this.tooltip,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = onTap == null ? disabledReason : null;
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(64),
      padding: const EdgeInsets.symmetric(
        horizontal: Material3Config.spacing12,
        vertical: Material3Config.spacing8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Material3Config.radiusLarge),
      ),
    );
    final content = Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: Material3Config.spacing8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (reason != null)
                Text(
                  reason,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    final button = primary
        ? FilledButton(onPressed: onTap, style: style, child: content)
        : FilledButton.tonal(onPressed: onTap, style: style, child: content);
    final message = tooltip;
    return message == null ? button : Tooltip(message: message, child: button);
  }
}
