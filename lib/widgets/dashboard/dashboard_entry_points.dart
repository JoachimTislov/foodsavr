import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../constants/material3_config.dart';
import '../../features/third_party_integration/oauth_controller.dart';
import '../../interfaces/i_auth_service.dart';
import '../../service_locator.dart';
import '../../services/barcode_scanner_service.dart';
import '../../utils/collection_types.dart';
import '../../utils/product_add_helper.dart';
import '../../views/collection_form_view.dart';
import '../../views/receipt_scan_view.dart';
import '../collection/quick_import_shopping_dialog.dart';
import '../common/refresh_on_return.dart';
import 'dashboard_action_button.dart';
import 'dashboard_export_dialog.dart';

/// The dashboard quick actions: every way to add, import and export data.
/// Receipt scanning needs a camera, and integrations are only offered where
/// one is available.
class DashboardEntryPoints extends StatefulWidget {
  /// Reloads the dashboard after an action changed the user's data.
  final Future<void> Function() onChanged;

  const DashboardEntryPoints({super.key, required this.onChanged});

  @override
  State<DashboardEntryPoints> createState() => _DashboardEntryPointsState();
}

class _DashboardEntryPointsState extends State<DashboardEntryPoints> {
  /// Narrowest button before the grid drops a column, never below two.
  static const double _minButtonWidth = 180;

  OAuthController? _integrations;

  /// Null while the camera is still being detected.
  bool? _hasCamera;

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<OAuthController>()) {
      _integrations = getIt<OAuthController>();
    }
    _detectAvailability();
  }

  void _detectAvailability() {
    _detectCamera();
    _loadIntegrations();
  }

  Future<void> _detectCamera() async {
    final hasCamera = await BarcodeScannerService.hasCamera();
    if (mounted && hasCamera != _hasCamera) {
      setState(() => _hasCamera = hasCamera);
    }
  }

  Future<void> _loadIntegrations() async {
    try {
      await _integrations?.loadConnections();
    } catch (e) {
      // The entry point stays hidden; Settings reports connection problems.
      getIt<Logger>().w('Could not load the integrations: $e');
    }
  }

  Future<void> _reloadIf(bool? changed) async {
    if (changed == true) await widget.onChanged();
  }

  Future<void> _addProduct() async =>
      _reloadIf(await ProductAddHelper.startAddProductFlow(context));

  Future<void> _scanReceipt() async {
    final userId = getIt<IAuthService>().getUserId();
    if (userId == null) return;
    final ingested = await Navigator.of(context, rootNavigator: true)
        .push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => ReceiptScanView(userId: userId),
          ),
        );
    await _reloadIf(ingested);
  }

  Future<void> _import() async =>
      _reloadIf(await QuickImportShoppingDialog.show(context));

  Future<void> _create(CollectionType type) async =>
      _reloadIf(await CollectionFormView.show(context, type: type));

  @override
  Widget build(BuildContext context) {
    // The camera setting and the connections can change on another tab.
    return RefreshOnReturn(
      onReturn: _detectAvailability,
      child: ListenableBuilder(
        listenable: _integrations ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) {
          final actions = <Widget>[
            DashboardActionButton(
              icon: Icons.add_box_outlined,
              label: 'dashboard.createProduct'.tr(),
              onTap: _addProduct,
              primary: true,
            ),
            DashboardActionButton(
              icon: Icons.receipt_long,
              label: 'receipt.scanShort'.tr(),
              onTap: _hasCamera == true ? _scanReceipt : null,
              disabledReason: _hasCamera == false
                  ? 'dashboard.noCamera'.tr()
                  : null,
              tooltip: _hasCamera == false
                  ? 'dashboard.noCameraHint'.tr()
                  : null,
            ),
            DashboardActionButton(
              icon: Icons.playlist_add,
              label: 'dashboard.import'.tr(),
              onTap: _import,
            ),
            DashboardActionButton(
              icon: Icons.download,
              label: 'dashboard.export'.tr(),
              onTap: () => DashboardExportDialog.show(context),
            ),
            DashboardActionButton(
              icon: Icons.add_shopping_cart,
              label: 'dashboard.createShoppingList'.tr(),
              onTap: () => _create(CollectionType.shoppingList),
            ),
            DashboardActionButton(
              icon: Icons.add_home_outlined,
              label: 'dashboard.createInventory'.tr(),
              onTap: () => _create(CollectionType.inventory),
            ),
            if (_integrations?.connections.isNotEmpty ?? false)
              DashboardActionButton(
                icon: Icons.hub_outlined,
                label: 'dashboard.integrations'.tr(),
                onTap: () => context.go('/settings'),
              ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              const spacing = Material3Config.spacing12;
              final columns = math.max(
                2,
                (constraints.maxWidth + spacing) ~/ (_minButtonWidth + spacing),
              );
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final action in actions)
                    SizedBox(width: width, child: action),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
