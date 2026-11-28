import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../constants/adaptive_layout.dart';
import '../../interfaces/i_auth_service.dart';
import '../../models/collection_model.dart';
import '../../service_locator.dart';
import '../../services/collection_service.dart';
import '../../services/data_export_service.dart';
import '../../services/product_service.dart';
import '../common/refresh_on_return.dart';
import 'export_quick_picker.dart';
import 'export_selection_panel.dart';
import 'settings_action_row.dart';
import 'settings_section.dart';

/// Exports the user's data: one tap on compact windows, granular selection on
/// wider ones.
class DataExportSection extends StatefulWidget {
  final DataExportService? service;
  final IAuthService? authService;

  const DataExportSection({super.key, this.service, this.authService});

  @override
  State<DataExportSection> createState() => _DataExportSectionState();
}

class _DataExportSectionState extends State<DataExportSection> {
  late final DataExportService _service =
      widget.service ??
      (getIt.isRegistered<DataExportService>()
          ? getIt<DataExportService>()
          : DataExportService(
              getIt<CollectionService>(),
              getIt<ProductService>(),
            ));
  late final IAuthService _authService =
      widget.authService ?? getIt<IAuthService>();

  List<Collection> _collections = const [];
  bool _loadFailed = false;
  bool _exporting = false;
  ExportFormat _format = ExportFormat.csv;

  // Deselections are tracked, so a newly created list starts out selected.
  Set<String> _excludedIds = {};
  bool _includeProducts = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _authService.getUserId();
    if (userId == null) return;
    try {
      final collections = await _service.loadCollections(userId);
      if (!mounted) return;
      setState(() {
        _collections = collections;
        _loadFailed = false;
      });
    } catch (e) {
      getIt<Logger>().w('Failed to load lists for export: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// Exports [selection], or everything when it is null.
  Future<void> _export(ExportSelection? selection) async {
    final userId = _authService.getUserId();
    if (_exporting || userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    String message;
    try {
      final (:file, :delivered) = await _service.export(
        userId: userId,
        selection: selection,
        format: _format,
      );
      message = delivered
          ? 'settings.export.success'.tr(namedArgs: {'file': file.fileName})
          : 'settings.export.unsupported'.tr();
    } catch (e, stack) {
      getIt<Logger>().e('Data export failed', error: e, stackTrace: stack);
      message = 'settings.export.error'.tr();
      // A selected list may be gone; show what exists now.
      await _load();
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _authService.getUserId() != null && !_exporting;
    void onFormatChanged(ExportFormat format) =>
        setState(() => _format = format);

    // The settings tab stays alive while hidden; reload when it returns.
    return RefreshOnReturn(
      onReturn: _load,
      child: SettingsSection(
        title: 'settings.export.title'.tr(),
        children: [
          if (_loadFailed)
            SettingsActionRow(
              icon: Icons.error_outline,
              title: 'settings.export.loadError'.tr(),
              action: TextButton(
                onPressed: _load,
                child: Text('common.tryAgain'.tr()),
              ),
            ),
          if (WindowSize.of(context).isCompact)
            ExportQuickPicker(
              collections: _collections,
              format: _format,
              onFormatChanged: onFormatChanged,
              onExport: enabled ? _export : null,
            )
          else
            ExportSelectionPanel(
              collections: _collections,
              excludedIds: _excludedIds,
              includeProducts: _includeProducts,
              format: _format,
              onFormatChanged: onFormatChanged,
              onSelectionChanged: (excludedIds, includeProducts) =>
                  setState(() {
                    _excludedIds = excludedIds;
                    _includeProducts = includeProducts;
                  }),
              onExport: enabled ? _export : null,
            ),
        ],
      ),
    );
  }
}
