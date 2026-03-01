import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigationView extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationView({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: 'dashboard.title'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: 'dashboard.myInventory'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.shopping_cart_outlined),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: 'dashboard.shoppingList'.tr(),
          ),
        ],
      ),
    );
  }
}
