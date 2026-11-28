import 'package:flutter/material.dart';

/// The title of a settings row. It wraps and never truncates.
class SettingsRowTitle extends StatelessWidget {
  final String text;
  final bool isDestructive;

  const SettingsRowTitle(this.text, {super.key, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: isDestructive ? theme.colorScheme.error : null,
      ),
    );
  }
}
