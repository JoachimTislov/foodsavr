import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../constants/adaptive_layout.dart';
import '../../constants/material3_config.dart';
import '../../utils/app_theme.dart';

/// One entry of [AppNavigationRail].
class AppNavigationRailItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AppNavigationRailItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Material 3 navigation rail. With [extended] the labels sit beside the icons.
///
/// Unlike [NavigationRail], each destination is exposed to assistive
/// technology as a tab, matching the bottom [NavigationBar] on compact windows.
class AppNavigationRail extends StatelessWidget {
  static const double collapsedWidth = 80;
  static const double extendedWidth = 256;

  final List<AppNavigationRailItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  const AppNavigationRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.extended = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: extended ? extendedWidth : collapsedWidth,
          child: Semantics(
            role: SemanticsRole.tabBar,
            explicitChildNodes: true,
            container: true,
            child: Padding(
              padding: const EdgeInsets.all(Material3Config.spacing12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: Material3Config.spacing12,
                      ),
                      child: MergeSemantics(
                        child: Semantics(
                          role: SemanticsRole.tab,
                          selected: i == selectedIndex,
                          child: _RailDestination(
                            item: items[i],
                            selected: i == selectedIndex,
                            extended: extended,
                            onTap: () => onDestinationSelected(i),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailDestination extends StatefulWidget {
  final AppNavigationRailItem item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  const _RailDestination({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  @override
  State<_RailDestination> createState() => _RailDestinationState();
}

class _RailDestinationState extends State<_RailDestination> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final focusColor = AppTheme.focusRingColorFor(theme.brightness);
    final isDesktop = AdaptiveLayout.isDesktop(context);
    final extendedRadius = isDesktop
        ? Material3Config.radiusDesktopLarge
        : Material3Config.radiusExtraLarge;
    final collapsedRadius = isDesktop
        ? Material3Config.radiusDesktopLarge
        : Material3Config.radiusLarge;

    final iconColor = widget.selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: widget.selected ? colors.onSurface : colors.onSurfaceVariant,
      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
    );
    final icon = Icon(
      widget.selected ? widget.item.selectedIcon : widget.item.icon,
      color: iconColor,
    );

    final content = widget.extended
        ? Container(
            height: 52,
            padding: const EdgeInsets.symmetric(
              horizontal: Material3Config.spacing16,
            ),
            decoration: _indicator(colors, focusColor, extendedRadius),
            child: Row(
              children: [
                icon,
                const SizedBox(width: Material3Config.spacing12),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: labelStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 32,
                alignment: Alignment.center,
                decoration: _indicator(colors, focusColor, collapsedRadius),
                child: icon,
              ),
              const SizedBox(height: Material3Config.spacing4),
              Text(
                widget.item.label,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          );

    return InkWell(
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
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          widget.extended ? extendedRadius : collapsedRadius,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: widget.extended ? 0 : Material3Config.spacing4,
        ),
        child: content,
      ),
    );
  }

  BoxDecoration _indicator(
    ColorScheme colors,
    Color focusColor,
    double radius,
  ) {
    final backgroundColor = widget.selected
        ? colors.secondaryContainer
        : _isHovered
        ? colors.onSurface.withValues(alpha: 0.06)
        : null;
    final border = _isFocused
        ? Border.all(color: focusColor, width: Material3Config.focusRingWidth)
        : _isHovered && !widget.selected
        ? Border.all(color: colors.outlineVariant)
        : null;

    return BoxDecoration(
      color: backgroundColor,
      border: border,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
