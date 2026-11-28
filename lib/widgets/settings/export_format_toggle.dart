import 'package:flutter/material.dart';

import '../../services/data_export_service.dart';
import 'segmented_pill.dart';

/// Chooses between CSV and JSON; the selected segment shows the active one.
class ExportFormatToggle extends StatelessWidget {
  final ExportFormat format;
  final ValueChanged<ExportFormat> onChanged;

  const ExportFormatToggle({
    super.key,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const csv = 'CSV';

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
