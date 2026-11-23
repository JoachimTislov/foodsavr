import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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

class _RailDestination extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final iconColor = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: selected ? colors.onSurface : colors.onSurfaceVariant,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    final icon = Icon(
      selected ? item.selectedIcon : item.icon,
      color: iconColor,
    );

    final content = extended
        ? Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: _indicator(colors, 28),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
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
                decoration: _indicator(colors, 16),
                child: icon,
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          );

    return InkWell(
      onTap: onTap,
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(extended ? 28 : 16),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: extended ? 0 : 4),
        child: content,
      ),
    );
  }

  BoxDecoration _indicator(ColorScheme colors, double radius) => BoxDecoration(
    color: selected ? colors.secondaryContainer : null,
    borderRadius: BorderRadius.circular(radius),
  );
}
