import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr/constants/material3_config.dart';
import 'package:foodsavr/features/third_party_integration/models/connection_model.dart';
import 'package:vector_graphics/vector_graphics.dart';

/// One store connection: logo, name, status, an explanation when it needs
/// attention, and its actions.
class ConnectionTile extends StatelessWidget {
  const ConnectionTile({
    super.key,
    required this.connection,
    required this.busy,
    required this.onConnect,
    required this.onDisconnect,
  });

  static const _logoSize = 40.0;

  final Connection connection;
  final bool busy;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final status = connection.status;
    final args = {'provider': connection.provider.toString()};

    final (IconData icon, String label, Color color) = switch (status) {
      Status.connected => (
        Icons.check_circle,
        'settings.integrations.status.connected'.tr(),
        colorScheme.primary,
      ),
      Status.reconnect_required => (
        Icons.warning_amber_rounded,
        'settings.integrations.status.reconnectRequired'.tr(),
        colorScheme.error,
      ),
      Status.unavailable => (
        Icons.cloud_off_outlined,
        'settings.integrations.status.unavailable'.tr(),
        colorScheme.tertiary,
      ),
      _ => (
        Icons.link_off,
        'settings.integrations.status.notConnected'.tr(),
        colorScheme.onSurfaceVariant,
      ),
    };
    final hint = switch (status) {
      Status.reconnect_required => 'settings.integrations.reconnectHint'.tr(
        namedArgs: args,
      ),
      Status.unavailable => 'settings.integrations.unavailableHint'.tr(
        namedArgs: args,
      ),
      _ => null,
    };

    final disconnect = 'settings.integrations.actions.disconnect'.tr();
    final actions = <Widget>[
      if (status == Status.not_configured)
        FilledButton(
          onPressed: busy ? null : onConnect,
          child: Text('settings.integrations.actions.connect'.tr()),
        ),
      if (status == Status.reconnect_required) ...[
        FilledButton.icon(
          onPressed: busy ? null : onConnect,
          icon: const Icon(Icons.refresh),
          label: Text('settings.integrations.actions.reconnect'.tr()),
        ),
        TextButton(
          onPressed: busy ? null : onDisconnect,
          child: Text(disconnect),
        ),
      ],
      if (status == Status.connected || status == Status.unavailable)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error),
          ),
          onPressed: busy ? null : onDisconnect,
          child: Text(disconnect),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.all(Material3Config.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  Material3Config.radiusSmall,
                ),
                child: ColoredBox(
                  color: Colors.white,
                  child: VectorGraphic(
                    loader: AssetBytesLoader(connection.provider.logoPath()),
                    height: _logoSize,
                    width: _logoSize,
                    placeholderBuilder: (context) => const SizedBox.square(
                      dimension: _logoSize,
                      child: Icon(Icons.storefront_outlined, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Material3Config.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.provider.toString(),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: Material3Config.spacing4),
                    Row(
                      children: [
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: Material3Config.spacing4),
                        Flexible(
                          child: Text(
                            label,
                            style: textTheme.labelMedium?.copyWith(
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: Material3Config.spacing12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(
                  Material3Config.radiusMedium,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Material3Config.spacing12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_clock_outlined, color: color),
                    const SizedBox(width: Material3Config.spacing12),
                    Expanded(
                      child: Text(
                        hint,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (connection.isAvailable && actions.isNotEmpty) ...[
            const SizedBox(height: Material3Config.spacing12),
            Wrap(
              spacing: Material3Config.spacing8,
              runSpacing: Material3Config.spacing8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
