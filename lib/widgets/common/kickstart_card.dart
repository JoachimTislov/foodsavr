import 'package:flutter/material.dart';

import '../../constants/material3_config.dart';

/// An actionable empty state: explains what is missing and offers the ways to
/// start. Sizes to its content up to [maxWidth] and wraps its actions, so it
/// fits compact and wide windows and works inside scroll views.
class KickstartCard extends StatelessWidget {
  static const double maxWidth = 560;

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final List<Widget> secondaryActions;

  const KickstartCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.secondaryActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Card.outlined(
        // Keeps the title, message and actions as separate semantics nodes.
        semanticContainer: false,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Material3Config.radiusExtraLarge),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 48, color: colorScheme.primary),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: actions,
              ),
              if (secondaryActions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: secondaryActions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
