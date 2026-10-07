import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart';

import '../controllers/dashboard_controller.dart';
import '../utils/collection_types.dart'; // Import CollectionType
import '../utils/product_add_helper.dart';
import '../widgets/common/retry_scaffold.dart';
import '../widgets/dashboard/overview_card.dart';
import '../widgets/dashboard/expiring_soon_section.dart';
import '../widgets/dashboard/dashboard_action_chip.dart';
import 'collection_form_view.dart';

class DashboardView extends WatchingWidget {
  const DashboardView({super.key});

  Future<void> _refreshDashboard() => getIt<DashboardController>().load();

  @override
  Widget build(BuildContext context) {
    final controller = watchIt<DashboardController>();
    final expiringSoon = controller.expiringSoon;
    final inventories = controller.inventories;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final today = DateFormat.yMMMMEEEEd(
      context.locale.toString(),
    ).format(DateTime.now());
    return RetryScaffold(
      fetchOnInit: true,
      onRefresh: _refreshDashboard,
      isBodyScrollable: true,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 24,
          top: MediaQuery.of(context).padding.top + 24,
          right: 24,
          bottom: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'dashboard.title'.tr(),
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      today,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            ExpiringSoonSection(products: expiringSoon),
            const SizedBox(height: 24),
            Text(
              'dashboard.overview'.tr(),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final cards = <Widget>[
                  OverviewCard(
                    title: 'product.all_products'.tr(),
                    subtitle: 'dashboard.browseProducts'.tr(),
                    icon: Icons.inventory_outlined,
                    iconColor: colorScheme.primary,
                    onTap: () => context.go('/dashboard/product-list'),
                  ),
                  if (inventories.length > 1)
                    OverviewCard(
                      title: 'dashboard.transfer'.tr(),
                      subtitle: 'dashboard.moveItems'.tr(),
                      icon: Icons.move_up,
                      iconColor: colorScheme.primary,
                      onTap: () => context.go('/dashboard/transfer'),
                    ),
                  OverviewCard(
                    title: 'dashboard.globalProducts'.tr(),
                    subtitle: 'dashboard.browseProducts'.tr(),
                    icon: Icons.public_outlined,
                    iconColor: colorScheme.primary,
                    onTap: () => context.go('/dashboard/global-products'),
                  ),
                ];
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: cards,
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'dashboard.actions'.tr(),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                DashboardActionChip(
                  icon: Icons.add_box_outlined,
                  label: 'dashboard.createProduct'.tr(),
                  color: colorScheme.primary,
                  onTap: () => ProductAddHelper.startAddProductFlow(context),
                ),
                const SizedBox(width: 8),
                DashboardActionChip(
                  icon: Icons.shopping_cart_outlined,
                  label: 'dashboard.createShoppingList'.tr(),
                  color: colorScheme.secondary,
                  onTap: () => CollectionFormView.show(
                    context,
                    type: CollectionType.shoppingList,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
