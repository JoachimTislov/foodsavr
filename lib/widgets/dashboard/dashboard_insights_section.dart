import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/material3_config.dart';
import '../../models/dashboard_insights.dart';
import '../../services/barcode_scanner_service.dart';
import '../../utils/dashboard_actions.dart';
import '../common/refresh_on_return.dart';
import 'insight_tile.dart';

/// Compact statistics about the user's products, expiries, shopping lists and
/// receipts. A statistic without data offers the action that would produce it,
/// which the quick actions then omit.
class DashboardInsightsSection extends StatefulWidget {
  final DashboardInsights insights;

  /// Reloads the dashboard after an action changed the user's data.
  final Future<void> Function() onChanged;

  const DashboardInsightsSection({
    super.key,
    required this.insights,
    required this.onChanged,
  });

  @override
  State<DashboardInsightsSection> createState() =>
      _DashboardInsightsSectionState();
}

class _DashboardInsightsSectionState extends State<DashboardInsightsSection> {
  /// Null while the camera is still being detected.
  bool? _hasCamera;

  @override
  void initState() {
    super.initState();
    _detectCamera();
  }

  Future<void> _detectCamera() async {
    final hasCamera = await BarcodeScannerService.hasCamera();
    if (mounted && hasCamera != _hasCamera) {
      setState(() => _hasCamera = hasCamera);
    }
  }

  Future<void> _run(DashboardAction action) async {
    if (await DashboardActions.run(context, action)) {
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final insights = widget.insights;
    final textTheme = Theme.of(context).textTheme;

    return RefreshOnReturn(
      onReturn: _detectCamera,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'dashboard.insights'.tr(),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: Material3Config.spacing12),
          Wrap(
            spacing: Material3Config.spacing12,
            runSpacing: Material3Config.spacing12,
            children: [
              if (insights.productCount > 0)
                InsightTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'dashboard.insightProducts'.tr(),
                  value: '${insights.productCount}',
                  onTap: () => context.go('/dashboard/my-products'),
                )
              else
                InsightTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'dashboard.insightProducts'.tr(),
                  actionLabel: 'product.add'.tr(),
                  onTap: () => _run(DashboardAction.addProduct),
                ),
              if (insights.hasExpiries) ...[
                InsightTile(
                  icon: Icons.schedule,
                  label: 'dashboard.expiringSoon'.tr(),
                  value: '${insights.expiringSoonCount}',
                  onTap: () =>
                      context.go('/dashboard/my-products?status=expiring'),
                ),
                InsightTile(
                  icon: Icons.error_outline,
                  label: 'dashboard.expired'.tr(),
                  value: '${insights.expiredCount}',
                  onTap: () =>
                      context.go('/dashboard/my-products?status=expired'),
                ),
              ] else
                InsightTile(
                  icon: Icons.schedule,
                  label: 'dashboard.expiringSoon'.tr(),
                  actionLabel: 'product.add_expiry'.tr(),
                  onTap: () => _run(DashboardAction.addExpiry),
                ),
              if (insights.shoppingListCount > 0)
                InsightTile(
                  icon: Icons.shopping_cart_outlined,
                  label: 'dashboard.insightShoppingItems'.tr(),
                  value: '${insights.shoppingListItemCount}',
                  onTap: () => context.go('/shopping-lists'),
                )
              else
                InsightTile(
                  icon: Icons.shopping_cart_outlined,
                  label: 'dashboard.insightShoppingItems'.tr(),
                  actionLabel: 'dashboard.createShoppingList'.tr(),
                  onTap: () => _run(DashboardAction.createShoppingList),
                ),
              if (insights.receiptCount > 0)
                InsightTile(
                  icon: Icons.receipt_long,
                  label: 'dashboard.insightReceipts'.tr(),
                  value: '${insights.receiptCount}',
                  detail: 'dashboard.insightReceiptsRecent'.plural(
                    insights.recentReceiptItemCount,
                    name: 'count',
                    namedArgs: {
                      'days': '${DashboardInsights.recentReceiptDays}',
                    },
                  ),
                  onTap: () => context.go('/dashboard/receipts'),
                )
              else
                InsightTile(
                  icon: Icons.receipt_long,
                  label: 'dashboard.insightReceipts'.tr(),
                  actionLabel: 'receipt.scanShort'.tr(),
                  note: _hasCamera == false ? 'dashboard.noCamera'.tr() : null,
                  onTap: _hasCamera == true
                      ? () => _run(DashboardAction.scanReceipt)
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
