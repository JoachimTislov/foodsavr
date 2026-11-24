import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart';

import '../controllers/dashboard_controller.dart';
import '../constants/adaptive_layout.dart';
import '../service_locator.dart';
import '../utils/collection_types.dart'; // Import CollectionType
import '../utils/product_add_helper.dart';
import '../widgets/common/content_constraint.dart';
import '../widgets/common/pwa_install_banner.dart';
import '../widgets/common/retry_scaffold.dart';
import '../widgets/dashboard/overview_card.dart';
import '../widgets/dashboard/expired_items_section.dart';
import '../widgets/dashboard/expiring_soon_section.dart';
import '../widgets/dashboard/dashboard_action_chip.dart';
import 'collection_form_view.dart';

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

    void createProduct() => ProductAddHelper.startAddProductFlow(context);
    void createShoppingList() =>
        CollectionFormView.show(context, type: CollectionType.shoppingList);

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
        : windowSize.isCompact
        ? GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            children: overviewCards,
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              const columns = 3;
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
                        minHeight: 128,
                      ),
                      child: card,
                    ),
                ],
              );
            },
          );

    final quickActionsTitle = Semantics(
      header: true,
      child: Text(
        'dashboard.actions'.tr(),
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );

    final quickActions = Row(
      children: [
        DashboardActionChip(
          icon: Icons.add_box_outlined,
          label: 'dashboard.createProduct'.tr(),
          color: colorScheme.primary,
          onTap: createProduct,
        ),
        const SizedBox(width: 8),
        DashboardActionChip(
          icon: Icons.shopping_cart_outlined,
          label: 'dashboard.createShoppingList'.tr(),
          color: colorScheme.secondary,
          onTap: createShoppingList,
        ),
      ],
    );

    final sections = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expired.isNotEmpty) ...[
          ExpiredItemsSection(products: expired),
          const SizedBox(height: 24),
        ],
        ExpiringSoonSection(products: expiringSoon),
      ],
    );

    final header = SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
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
          if (isExpanded)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                quickActionsTitle,
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: createProduct,
                      icon: const Icon(Icons.add_box_outlined),
                      label: Text('dashboard.createProduct'.tr()),
                    ),
                    FilledButton.icon(
                      onPressed: createShoppingList,
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text('dashboard.createShoppingList'.tr()),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );

    final body = isExpanded
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: sections),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    overviewTitle,
                    const SizedBox(height: 12),
                    overviewGrid,
                  ],
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sections,
              const SizedBox(height: 24),
              overviewTitle,
              const SizedBox(height: 12),
              overviewGrid,
              const SizedBox(height: 24),
              quickActionsTitle,
              const SizedBox(height: 12),
              quickActions,
            ],
          );

    final padding = isExpanded ? 32.0 : 24.0;
    return RetryScaffold(
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
              SizedBox(height: isExpanded ? 24 : 32),
              body,
              const PwaInstallBanner(margin: EdgeInsets.only(top: 24)),
            ],
          ),
        ),
      ),
    );
  }
}
