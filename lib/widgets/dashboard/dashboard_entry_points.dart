import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../constants/material3_config.dart';
import '../../features/third_party_integration/oauth_controller.dart';
import '../../models/dashboard_insights.dart';
import '../../service_locator.dart';
import '../../services/barcode_scanner_service.dart';
import '../../utils/collection_types.dart';
import '../../utils/collection_create_flow.dart';
import '../../utils/dashboard_actions.dart';
import '../collection/quick_import_shopping_dialog.dart';
import '../common/refresh_on_return.dart';
import 'dashboard_action_button.dart';
import 'dashboard_export_dialog.dart';

/// The dashboard quick actions: every way to add, import and export data.
/// Actions listed in [hidden] are offered elsewhere on the dashboard and
/// skipped here. Receipt scanning needs a camera, and integrations are only
/// offered where one is available.
class DashboardEntryPoints extends StatefulWidget {
  /// Reloads the dashboard after an action changed the user's data.
  final Future<void> Function() onChanged;

  /// Actions already offered by an insight tile.
  final Set<DashboardAction> hidden;

  /// Whether more than one inventory exists, so items can move between them.
  final bool canTransfer;

  const DashboardEntryPoints({
    super.key,
    required this.onChanged,
    this.hidden = const {},
    this.canTransfer = false,
  });

  @override
  State<DashboardEntryPoints> createState() => _DashboardEntryPointsState();
}

class _DashboardEntryPointsState extends State<DashboardEntryPoints> {
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
    final hasCamera = await BarcodeScannerService.hasTextScanner();
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

  Future<void> _run(DashboardAction action) async =>
      _reloadIf(await DashboardActions.run(context, action));

  Future<void> _import() async =>
      _reloadIf(await QuickImportShoppingDialog.show(context));

  Future<void> _createInventory() async => _reloadIf(
    await CollectionCreateFlow.run(context, CollectionType.inventory) != null,
  );

  @override
  Widget build(BuildContext context) {
    // The camera setting and the connections can change on another tab.
    return RefreshOnReturn(
      onReturn: _detectAvailability,
      child: ListenableBuilder(
        listenable: _integrations ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) {
          return Wrap(
            spacing: Material3Config.spacing12,
            runSpacing: Material3Config.spacing12,
            children: [
              if (!widget.hidden.contains(DashboardAction.addProduct))
                DashboardActionButton(
                  icon: Icons.add_box_outlined,
                  label: 'dashboard.createProduct'.tr(),
                  onTap: () => _run(DashboardAction.addProduct),
                  primary: true,
                ),
              if (!widget.hidden.contains(DashboardAction.addExpiry))
                DashboardActionButton(
                  icon: Icons.event_available_outlined,
                  label: 'product.add_expiry'.tr(),
                  onTap: () => _run(DashboardAction.addExpiry),
                ),
              if (!widget.hidden.contains(DashboardAction.scanReceipt))
                DashboardActionButton(
                  icon: Icons.receipt_long,
                  label: 'receipt.scanShort'.tr(),
                  onTap: _hasCamera == true
                      ? () => _run(DashboardAction.scanReceipt)
                      : null,
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
              if (!widget.hidden.contains(DashboardAction.createShoppingList))
                DashboardActionButton(
                  icon: Icons.add_shopping_cart,
                  label: 'dashboard.createShoppingList'.tr(),
                  onTap: () => _run(DashboardAction.createShoppingList),
                ),
              DashboardActionButton(
                icon: Icons.add_home_outlined,
                label: 'dashboard.createInventory'.tr(),
                onTap: _createInventory,
              ),
              DashboardActionButton(
                icon: Icons.public_outlined,
                label: 'dashboard.globalProducts'.tr(),
                onTap: () => context.go('/dashboard/registry'),
              ),
              if (widget.canTransfer)
                DashboardActionButton(
                  icon: Icons.move_up,
                  label: 'dashboard.transfer'.tr(),
                  onTap: () => context.go('/dashboard/transfer'),
                ),
              if (_integrations?.connections.isNotEmpty ?? false)
                DashboardActionButton(
                  icon: Icons.hub_outlined,
                  label: 'dashboard.integrations'.tr(),
                  onTap: () => context.go('/settings'),
                ),
            ],
          );
        },
      ),
    );
  }
}
