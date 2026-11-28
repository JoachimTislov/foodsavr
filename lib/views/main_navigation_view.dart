import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/adaptive_layout.dart';
import '../routes/page_trail.dart';
import '../widgets/common/app_breadcrumbs.dart';
import '../widgets/common/app_navigation_rail.dart';

/// App shell: a bottom navigation bar on compact windows, and on wider ones a
/// navigation rail (labels beside the icons from
/// [AdaptiveLayout.extendedRailBreakpoint]) with profile and settings as slim
/// buttons at its bottom, and breadcrumbs above the content.
class MainNavigationView extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  /// Shown above every branch, such as the pending-sync banner.
  final Widget? statusBanner;

  const MainNavigationView({
    super.key,
    required this.navigationShell,
    this.statusBanner,
  });

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  // Keeps the branch navigators alive when the window crosses a breakpoint.
  final _bodyKey = GlobalKey();

  void _onDestinationSelected(int index) {
    final shell = widget.navigationShell;
    if (index == shell.currentIndex) PageTrail.branches[index].popTo(null);
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    // `tr()` alone does not rebuild the labels on a language change.
    EasyLocalization.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final selectedIndex = widget.navigationShell.currentIndex;
    final shell = KeyedSubtree(key: _bodyKey, child: widget.navigationShell);
    final banner = widget.statusBanner;
    final body = AppBreadcrumbs(
      trail: PageTrail.branches[selectedIndex],
      child: banner == null
          ? shell
          : Column(
              children: [
                banner,
                Expanded(child: shell),
              ],
            ),
    );

    if (WindowSize.fromWidth(width).isCompact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            for (final item in [..._items, ..._footerItems])
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.labelKey.tr(),
              ),
          ],
        ),
      );
    }

    AppNavigationRailItem railItem(_NavItem item) => AppNavigationRailItem(
      icon: item.icon,
      selectedIcon: item.selectedIcon,
      label: item.labelKey.tr(),
    );
    return Scaffold(
      body: Row(
        children: [
          AppNavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            extended: width >= AdaptiveLayout.extendedRailBreakpoint,
            items: [for (final item in _items) railItem(item)],
            footerItems: [for (final item in _footerItems) railItem(item)],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String labelKey;

  const _NavItem(this.icon, this.selectedIcon, this.labelKey);
}

/// The main destinations, in branch order.
const _items = [
  _NavItem(Icons.home_outlined, Icons.home, 'dashboard.title'),
  _NavItem(
    Icons.inventory_2_outlined,
    Icons.inventory_2,
    'dashboard.myInventory',
  ),
  _NavItem(
    Icons.shopping_cart_outlined,
    Icons.shopping_cart,
    'dashboard.shoppingList',
  ),
];

/// Profile and settings, the branches after [_items].
const _footerItems = [
  _NavItem(Icons.person_outline, Icons.person, 'profile.title'),
  _NavItem(Icons.settings_outlined, Icons.settings, 'settings.title'),
];
