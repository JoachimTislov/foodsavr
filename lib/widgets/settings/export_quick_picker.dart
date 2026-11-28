import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/collection_model.dart';
import '../../services/data_export_service.dart';
import '../../utils/collection_types.dart';
import 'export_collection_type_label.dart';
import 'export_format_toggle.dart';
import 'settings_row_subtitle.dart';
import 'settings_row_title.dart';

/// Compact export: everything in one tap, or tap a single list.
class ExportQuickPicker extends StatelessWidget {
  final List<Collection> collections;
  final ExportFormat format;
  final ValueChanged<ExportFormat> onFormatChanged;

  /// Null while exporting is unavailable. A null selection means everything.
  final ValueChanged<ExportSelection?>? onExport;

  const ExportQuickPicker({
    super.key,
    required this.collections,
    required this.format,
    required this.onFormatChanged,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final export = onExport;
    final items = [
      for (final collection in collections)
        (
          icon: collection.type == CollectionType.inventory
              ? Icons.inventory_2_outlined
              : Icons.shopping_cart_outlined,
          title: collection.name,
          subtitle: exportCollectionTypeLabel(collection.type),
          selection: ExportSelection(collectionIds: {collection.id}),
        ),
      (
        icon: Icons.category_outlined,
        title: 'settings.export.products'.tr(),
        subtitle: 'settings.export.productsHint'.tr(),
        selection: const ExportSelection(includeProducts: true),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: export == null ? null : () => export(null),
                icon: const Icon(Icons.download),
                label: Text(
                  'settings.export.exportAll'.tr(
                    namedArgs: {'format': format.extension.toUpperCase()},
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  SettingsRowSubtitle('settings.export.format'.tr()),
                  ExportFormatToggle(
                    format: format,
                    onChanged: onFormatChanged,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SettingsRowSubtitle('settings.export.exportOne'.tr()),
            ],
          ),
        ),
        for (final item in items)
          ListTile(
            leading: Icon(item.icon),
            title: SettingsRowTitle(item.title),
            subtitle: SettingsRowSubtitle(item.subtitle),
            trailing: const Icon(Icons.file_download_outlined),
            onTap: export == null ? null : () => export(item.selection),
          ),
      ],
    );
  }
}
