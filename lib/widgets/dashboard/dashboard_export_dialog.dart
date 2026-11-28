import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../common/adaptive_sheet.dart';
import '../settings/data_export_section.dart';

/// Exports data from a modal, so the user stays on the dashboard.
class DashboardExportDialog extends StatelessWidget {
  const DashboardExportDialog({super.key});

  static Future<void> show(BuildContext context) => AdaptiveSheet.show<void>(
    context,
    builder: (_) => const DashboardExportDialog(),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'common.close'.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const Flexible(
          child: SingleChildScrollView(child: DataExportSection()),
        ),
      ],
    );
  }
}
