import 'package:flutter/material.dart';

import '../interfaces/i_auth_service.dart';
import '../models/dashboard_insights.dart';
import '../service_locator.dart';
import '../views/batch_expiry_view.dart';
import '../views/receipt_scan_view.dart';
import 'collection_create_flow.dart';
import 'collection_types.dart';
import 'product_add_helper.dart';

/// Runs the dashboard actions shared by the insight tiles and the quick
/// actions.
class DashboardActions {
  const DashboardActions._();

  /// Runs [action]; true when it changed the user's data.
  static Future<bool> run(BuildContext context, DashboardAction action) {
    return switch (action) {
      DashboardAction.addProduct => ProductAddHelper.startAddProductFlow(
        context,
      ).then((r) => r == true),
      DashboardAction.addExpiry => BatchExpiryView.show(
        context,
      ).then((r) => r == true),
      DashboardAction.scanReceipt => _scanReceipt(context),
      DashboardAction.createShoppingList => CollectionCreateFlow.run(
        context,
        CollectionType.shoppingList,
      ).then((collection) => collection != null),
    };
  }

  static Future<bool> _scanReceipt(BuildContext context) async {
    final userId = getIt<IAuthService>().getUserId();
    if (userId == null) return false;
    final ingested = await Navigator.of(context, rootNavigator: true)
        .push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => ReceiptScanView(userId: userId),
          ),
        );
    return ingested == true;
  }
}
