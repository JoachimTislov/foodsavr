import 'package:flutter/material.dart';

import '../../constants/adaptive_layout.dart';
import '../../constants/material3_config.dart';
import '../../utils/app_theme.dart';

/// Reusable navigation card widget with responsive radii and desktop hover/focus
/// interaction affordances.
class NavigationCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const NavigationCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<NavigationCard> createState() => _NavigationCardState();
}

class _NavigationCardState extends State<NavigationCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = AdaptiveLayout.tokensOf(context);
    final isDesktop = tokens.windowSize.isExpanded;
    final cardRadius = BorderRadius.circular(tokens.cardRadius);
    final focusColor = AppTheme.focusRingColorFor(theme.brightness);

    final borderSide = _isFocused
        ? BorderSide(color: focusColor, width: Material3Config.focusRingWidth)
        : _isHovered
        ? BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.45),
            width: 1.5,
          )
        : isDesktop
        ? BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.7))
        : BorderSide.none;

    return Card(
      elevation: _isHovered
          ? Material3Config.elevationLevel2
          : isDesktop
          ? Material3Config.elevationLevel0
          : Material3Config.elevationLevel1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: cardRadius, side: borderSide),
      child: InkWell(
        onTap: widget.onTap,
        mouseCursor: SystemMouseCursors.click,
        onHover: (hovered) {
          if (_isHovered != hovered) {
            setState(() => _isHovered = hovered);
          }
        },
        onFocusChange: (focused) {
          if (_isFocused != focused) {
            setState(() => _isFocused = focused);
          }
        },
        borderRadius: cardRadius,
        child: Padding(
          padding: tokens.cardPadding,
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(tokens.controlRadius),
                ),
                child: Icon(
                  widget.icon,
                  size: 32,
                  color: Material3Config.getOnContainerColor(
                    context,
                    widget.color,
                  ),
                ),
              ),
              const SizedBox(width: Material3Config.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: Material3Config.spacing4),
                    Text(
                      widget.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
}
