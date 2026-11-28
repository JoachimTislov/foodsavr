import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/collection_model.dart';
import '../../services/data_export_service.dart';
import 'export_collection_type_label.dart';
import 'export_format_toggle.dart';
import 'settings_row_subtitle.dart';
import 'settings_row_title.dart';

/// Granular export for wide windows: everything, some, or one.
class ExportSelectionPanel extends StatelessWidget {
  static const _itemPadding = EdgeInsets.only(left: 32, right: 16);

  final List<Collection> collections;
  final Set<String> excludedIds;
  final bool includeProducts;
  final ExportFormat format;
  final ValueChanged<ExportFormat> onFormatChanged;
  final void Function(Set<String> excludedIds, bool includeProducts)
  onSelectionChanged;

  /// Null while exporting is unavailable. A null selection means everything.
  final ValueChanged<ExportSelection?>? onExport;

  const ExportSelectionPanel({
    super.key,
    required this.collections,
    required this.excludedIds,
    required this.includeProducts,
    required this.format,
    required this.onFormatChanged,
    required this.onSelectionChanged,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIds = {
      for (final collection in collections)
        if (!excludedIds.contains(collection.id)) collection.id,
    };
    // The products catalog counts as one item.
    final total = collections.length + 1;
    final selected = selectedIds.length + (includeProducts ? 1 : 0);
    final everything = selected == total;
    final export = onExport;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SettingsRowSubtitle('settings.export.description'.tr()),
        ),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          tristate: true,
          value: everything ? true : (selected == 0 ? false : null),
          title: SettingsRowTitle('settings.export.everything'.tr()),
          onChanged: (_) => onSelectionChanged(
            everything ? {for (final c in collections) c.id} : {},
            !everything,
          ),
        ),
        for (final collection in collections)
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: _itemPadding,
            value: selectedIds.contains(collection.id),
            title: SettingsRowTitle(collection.name),
            subtitle: SettingsRowSubtitle(
              exportCollectionTypeLabel(collection.type),
            ),
            onChanged: (checked) => onSelectionChanged(
              checked == true
                  ? excludedIds.difference({collection.id})
                  : {...excludedIds, collection.id},
              includeProducts,
            ),
          ),
        CheckboxListTile(
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: _itemPadding,
          value: includeProducts,
          title: SettingsRowTitle('settings.export.products'.tr()),
          subtitle: SettingsRowSubtitle('settings.export.productsHint'.tr()),
          onChanged: (checked) =>
              onSelectionChanged(excludedIds, checked == true),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              ExportFormatToggle(
                format: format,
                onChanged: onFormatChanged,
                markDefault: true,
              ),
              SettingsRowSubtitle(
                'settings.export.selected'.tr(
                  namedArgs: {'selected': '$selected', 'total': '$total'},
                ),
              ),
              FilledButton.icon(
                onPressed: export == null || selected == 0
                    ? null
                    : () => export(
                        everything
                            ? null
                            : ExportSelection(
                                collectionIds: selectedIds,
                                includeProducts: includeProducts,
                              ),
                      ),
                icon: const Icon(Icons.download),
                label: Text('settings.export.download'.tr()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
