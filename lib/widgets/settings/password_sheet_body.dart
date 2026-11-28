import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Layout of the small password modals: title, fields, error and actions.
class PasswordSheetBody extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> fields;
  final String? error;
  final String submitLabel;
  final bool busy;
  final VoidCallback onSubmit;

  const PasswordSheetBody({
    super.key,
    required this.title,
    this.description,
    required this.fields,
    required this.error,
    required this.submitLabel,
    required this.busy,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          for (final field in fields) ...[const SizedBox(height: 16), field],
          if (error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              FilledButton(
                onPressed: busy ? null : onSubmit,
                child: Text(submitLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
