import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr/constants/material3_config.dart';
import 'package:foodsavr/injection.dart';
import 'package:go_router/go_router.dart';

import '../oauth_controller.dart';
import 'connection_tile.dart';
import 'disconnect_confirmation.dart';

class OAuthConnectionsList extends StatelessWidget {
  final OAuthController controller;

  OAuthConnectionsList({super.key, OAuthController? controller})
    : controller = controller ?? getIt<OAuthController>() {
    this.controller.loadConnections();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final connections = controller.connections;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final divider = Divider(
          height: 1,
          indent: Material3Config.spacing16,
          endIndent: Material3Config.spacing16,
          color: colorScheme.outlineVariant.withValues(alpha: 0.1),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'settings.integrations.title'.tr().toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: Material3Config.spacing8),
            Material(
              color: colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  Material3Config.radiusLarge,
                ),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (connections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(Material3Config.spacing16),
                      child: Text(
                        'settings.integrations.noConnections'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final (i, connection) in connections.indexed) ...[
                    if (i > 0) divider,
                    ConnectionTile(
                      connection: connection,
                      busy: controller.activeProvider == connection.provider,
                      onConnect: () => context.go(
                        '/settings/web-view?provider=${connection.provider.name}',
                      ),
                      onDisconnect: () async {
                        final provider = connection.provider;
                        if (await DisconnectConfirmation.show(
                          context,
                          provider,
                        )) {
                          await controller.disconnect(provider);
                        }
                      },
                    ),
                  ],
                  if (controller.connectionFailed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Material3Config.spacing16,
                        0,
                        Material3Config.spacing16,
                        Material3Config.spacing16,
                      ),
                      child: Text(
                        'settings.integrations.connectionFailed'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
