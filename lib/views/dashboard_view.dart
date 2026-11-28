import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:watch_it/watch_it.dart';

import '../controllers/dashboard_controller.dart';
import '../constants/adaptive_layout.dart';
import '../service_locator.dart';
import '../utils/collection_types.dart'; // Import CollectionType
import '../utils/product_add_helper.dart';
import '../widgets/collection/account_kickstart_card.dart';
import '../widgets/common/content_constraint.dart';
import '../widgets/common/pwa_install_banner.dart';
import '../widgets/common/refresh_on_return.dart';
import '../widgets/common/retry_scaffold.dart';
import '../widgets/dashboard/dashboard_collections_section.dart';
import '../widgets/dashboard/dashboard_entry_points.dart';
import '../widgets/dashboard/overview_card.dart';
import '../widgets/dashboard/expired_items_section.dart';
import '../widgets/dashboard/expiring_soon_section.dart';

class DashboardView extends WatchingWidget {
  const DashboardView({super.key});

  /// Content width at Expanded, per the Claude Design dashboard board.
  static const double _expandedMaxWidth = 1120;

  Future<void> _refreshDashboard() => getIt<DashboardController>().refresh();

  @override
  Widget build(BuildContext context) {
    final controller = watchIt<DashboardController>();
    final expired = controller.expired;
    final expiringSoon = controller.expiringSoon;
    final inventories = controller.inventories;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final windowSize = WindowSize.of(context);
    final isExpanded = windowSize.isExpanded;
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

    Future<void> registerExpiry() async {
      final added = await ProductAddHelper.startExpiryFirstFlow(context);
      if (added == true) await reload();
    }

    final overviewCards = <Widget>[
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

    final overviewTitle = Text(
      'dashboard.overview'.tr(),
      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );

    // Medium and Expanded let cards grow beyond their minimum heights.
    final overviewGrid = isExpanded
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in overviewCards) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 104),
                  child: card,
                ),
                if (card != overviewCards.last) const SizedBox(height: 12),
              ],
            ],
          )
        : LayoutBuilder(
            // Content-sized cards (no fixed aspect ratio) so large text grows
            // the card instead of overflowing it.
            builder: (context, constraints) {
              final columns = windowSize.isCompact ? 2 : 3;
              const spacing = 12.0;
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final card in overviewCards)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: cardWidth,
                        maxWidth: cardWidth,
                        minHeight: windowSize.isCompact ? 104 : 128,
                      ),
                      child: card,
                    ),
                ],
              );
            },
          );

    final quickActions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'dashboard.actions'.tr(),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        DashboardEntryPoints(onChanged: reload),
      ],
    );

    final sections = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expired.isNotEmpty) ...[
          ExpiredItemsSection(products: expired),
          const SizedBox(height: 24),
        ],
        ExpiringSoonSection(
          products: expiringSoon,
          onRegisterExpiry: registerExpiry,
        ),
        const SizedBox(height: 24),
        DashboardCollectionsSection(
          type: CollectionType.inventory,
          collections: inventories,
          productCounts: controller.productCounts,
          onChanged: reload,
        ),
        const SizedBox(height: 24),
        DashboardCollectionsSection(
          type: CollectionType.shoppingList,
          collections: controller.shoppingLists,
          productCounts: controller.productCounts,
          onChanged: reload,
        ),
      ],
    );

    final header = Column(
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
    );

    final overview = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [overviewTitle, const SizedBox(height: 12), overviewGrid],
    );

    final body = isExpanded
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: sections),
              const SizedBox(width: 24),
              Expanded(child: overview),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [sections, const SizedBox(height: 24), overview],
          );

    final padding = isExpanded ? 32.0 : 24.0;
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
          maxWidth: isExpanded
              ? _expandedMaxWidth
              : AdaptiveLayout.pageMaxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 24),
              if (controller.isEmptyAccount) ...[
                const AccountKickstartCard(),
                const SizedBox(height: 24),
              ],
              quickActions,
              const SizedBox(height: 24),
              body,
              const PwaInstallBanner(margin: EdgeInsets.only(top: 24)),
            ],
          ),
        ),
      ),
    );
    return RefreshOnReturn(onReturn: reload, child: scaffold);
  }
}
