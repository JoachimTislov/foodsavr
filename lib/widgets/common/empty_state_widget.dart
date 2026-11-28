import 'package:flutter/material.dart';

import '../../constants/adaptive_layout.dart';
import '../../constants/material3_config.dart';
import '../../utils/platform_capabilities.dart';

/// Reusable empty state widget with reliably centered copy and optional action
/// controls across mobile, tablet, and wide desktop viewports.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final capabilities = PlatformCapabilities.of(context);
    final tokens = AdaptiveLayout.tokensFor(capabilities.windowSize);
    final iconSize = capabilities.preferDesktopAffordances ? 56.0 : 64.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AdaptiveLayout.emptyStateMaxWidth,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.pagePadding.left,
            vertical: tokens.sectionSpacing,
          ),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: iconSize, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: Material3Config.spacing16),
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: Material3Config.spacing8),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  SizedBox(height: tokens.sectionSpacing),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: tokens.itemSpacing,
                      runSpacing: tokens.itemSpacing,
                      children: actions,
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
