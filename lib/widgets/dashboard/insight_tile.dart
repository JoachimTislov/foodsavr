import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';

/// One compact dashboard statistic. With a [value] it reads as a figure; with
/// an [actionLabel] instead, it offers the action that would produce the data.
/// A null [onTap] renders the tile inert; [note] then says why.
class InsightTile extends StatelessWidget {
  static const double minWidth = 152;
  static const double maxWidth = 240;

  final IconData icon;
  final String label;
  final String? value;
  final String? detail;
  final String? actionLabel;
  final String? note;
  final VoidCallback? onTap;

  const InsightTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.detail,
    this.actionLabel,
    this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final action = actionLabel;
    final enabled = onTap != null;
    final radius = BorderRadius.circular(Material3Config.radiusLarge);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      child: Material(
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(Material3Config.spacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(height: Material3Config.spacing8),
                if (value != null)
                  Text(
                    value!,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (action != null) ...[
                  const SizedBox(height: Material3Config.spacing8),
                  Text(
                    enabled || note == null ? action : note!,
                    style: textTheme.labelLarge?.copyWith(
                      color: enabled
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
