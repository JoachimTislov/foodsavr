import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/data_export_service.dart';
import 'segmented_pill.dart';

/// Chooses between CSV, the default, and JSON.
class ExportFormatToggle extends StatelessWidget {
  final ExportFormat format;
  final ValueChanged<ExportFormat> onChanged;

  /// Whether CSV is labelled as the default.
  final bool markDefault;

  const ExportFormatToggle({
    super.key,
    required this.format,
    required this.onChanged,
    this.markDefault = false,
  });

  @override
  Widget build(BuildContext context) {
    final csv = markDefault ? 'settings.export.csvDefault'.tr() : 'CSV';

    return SegmentedPill<ExportFormat>(
      segments: [
        (value: ExportFormat.csv, label: csv, icon: null, semanticLabel: csv),
        (
          value: ExportFormat.json,
          label: 'JSON',
          icon: null,
          semanticLabel: 'JSON',
        ),
      ],
      selected: format,
      onSelected: onChanged,
    );
  }
}
