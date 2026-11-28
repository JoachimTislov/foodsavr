import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:watch_it/watch_it.dart';

import '../constants/adaptive_layout.dart';
import '../constants/material3_config.dart';
import '../controllers/dashboard_controller.dart';
import '../service_locator.dart';
import '../utils/collection_types.dart';
import '../widgets/collection/account_kickstart_card.dart';
import '../widgets/common/content_constraint.dart';
import '../widgets/common/pwa_install_banner.dart';
import '../widgets/common/refresh_on_return.dart';
import '../widgets/common/retry_scaffold.dart';
import '../widgets/dashboard/dashboard_collections_section.dart';
import '../widgets/dashboard/dashboard_entry_points.dart';
import '../widgets/dashboard/dashboard_insights_section.dart';
import '../widgets/dashboard/expired_items_section.dart';
import '../widgets/dashboard/expiring_soon_section.dart';

/// The dashboard: one compact column at every width, so widgets never share a
/// row and cannot collide.
class DashboardView extends WatchingWidget {
  const DashboardView({super.key});

  Future<void> _refreshDashboard() => getIt<DashboardController>().refresh();

  @override
  Widget build(BuildContext context) {
    final controller = watchIt<DashboardController>();
    final insights = controller.insights;
    final inventories = controller.inventories;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final today = DateFormat.yMMMMEEEEd(
      context.locale.toString(),
    ).format(DateTime.now());

    Future<void> reload() async {
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      try {
        await controller.load();
      } catch (e, stack) {
        getIt<Logger>().w(
          'Dashboard reload failed',
          error: e,
          stackTrace: stack,
        );
        messenger?.showSnackBar(
          SnackBar(content: Text('common.error_loading_data'.tr())),
        );
      }
    }

    final padding = WindowSize.of(context).isExpanded
        ? Material3Config.spacing32
        : Material3Config.spacing24;
    const gap = SizedBox(height: Material3Config.spacing24);
    final scaffold = RetryScaffold(
      fetchOnInit: true,
      onRefresh: _refreshDashboard,
      isBodyScrollable: true,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: padding,
          top: MediaQuery.of(context).padding.top + padding,
          right: padding,
          bottom: padding,
        ),
        child: ContentConstraint(
          maxWidth: AdaptiveLayout.pageMaxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              gap,
              if (controller.isEmptyAccount) ...[
                const AccountKickstartCard(),
                gap,
              ],
              DashboardInsightsSection(insights: insights, onChanged: reload),
              gap,
              Semantics(
                header: true,
                child: Text(
                  'dashboard.actions'.tr(),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: Material3Config.spacing12),
              DashboardEntryPoints(
                onChanged: reload,
                hidden: insights.emptyActions,
                canTransfer: inventories.length > 1,
              ),
              gap,
              if (controller.expired.isNotEmpty) ...[
                ExpiredItemsSection(products: controller.expired),
                gap,
              ],
              if (controller.expiringSoon.isNotEmpty) ...[
                ExpiringSoonSection(products: controller.expiringSoon),
                gap,
              ],
              DashboardCollectionsSection(
                type: CollectionType.inventory,
                collections: inventories,
                productCounts: controller.productCounts,
                onChanged: reload,
              ),
              gap,
              DashboardCollectionsSection(
                type: CollectionType.shoppingList,
                collections: controller.shoppingLists,
                productCounts: controller.productCounts,
                onChanged: reload,
              ),
              const PwaInstallBanner(margin: EdgeInsets.only(top: 24)),
            ],
          ),
        ),
      ),
    );
    return RefreshOnReturn(onReturn: reload, child: scaffold);
  }
}
