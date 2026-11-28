import 'package:flutter/material.dart';

/// Context or status under a settings row title. It wraps and never truncates.
class SettingsRowSubtitle extends StatelessWidget {
  final String text;

  const SettingsRowSubtitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
