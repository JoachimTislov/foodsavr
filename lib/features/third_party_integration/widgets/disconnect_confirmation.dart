import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr/constants/adaptive_layout.dart';
import 'package:foodsavr/constants/material3_config.dart';
import 'package:foodsavr/features/third_party_integration/models/provider_model.dart';

/// Asks the user to confirm disconnecting [provider]: a bottom sheet on
/// compact windows, a dialog beyond.
class DisconnectConfirmation extends StatelessWidget {
  const DisconnectConfirmation({
    super.key,
    required this.provider,
    required this.sheet,
  });

  final Provider provider;
  final bool sheet;

  /// Resolves to true when the user confirms.
  static Future<bool> show(BuildContext context, Provider provider) async {
    final confirmed = WindowSize.of(context).isCompact
        ? await showModalBottomSheet<bool>(
            context: context,
            showDragHandle: true,
            builder: (_) =>
                DisconnectConfirmation(provider: provider, sheet: true),
          )
        : await showDialog<bool>(
            context: context,
            builder: (_) =>
                DisconnectConfirmation(provider: provider, sheet: false),
          );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final args = {'provider': provider.toString()};
    final title = Text(
      'settings.integrations.disconnectDialog.title'.tr(namedArgs: args),
    );
    final description = Text(
      'settings.integrations.disconnectDialog.description'.tr(namedArgs: args),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
      ),
      onPressed: () => Navigator.of(context).pop(true),
      child: Text('settings.integrations.actions.disconnect'.tr()),
    );
    final cancel = TextButton(
      onPressed: () => Navigator.of(context).pop(false),
      child: Text('common.cancel'.tr()),
    );

    if (!sheet) {
      return AlertDialog(
        title: title,
        content: description,
        actions: [cancel, confirm],
      );
    }

    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Material3Config.spacing24,
          0,
          Material3Config.spacing24,
          Material3Config.spacing24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTextStyle.merge(style: textTheme.titleLarge, child: title),
            const SizedBox(height: Material3Config.spacing8),
            DefaultTextStyle.merge(
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              child: description,
            ),
            const SizedBox(height: Material3Config.spacing24),
            confirm,
            const SizedBox(height: Material3Config.spacing8),
            cancel,
          ],
        ),
      ),
    );
  }
}
