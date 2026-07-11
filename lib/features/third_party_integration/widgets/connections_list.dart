import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr/features/third_party_integration/models/m_connection.dart';
import 'package:foodsavr/injection.dart';
import 'package:go_router/go_router.dart';

import '../oauth_controller.dart';

class OAuthConnectionsList extends StatelessWidget {
  final OAuthController controller = getIt<OAuthController>();

  OAuthConnectionsList({super.key}) {
    controller.loadConnections();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final connections = controller.connections;
        if (connections.isEmpty) {
          return Text('No connections');
        }

        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'settings.integrations.title'.tr().toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < connections.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.1,
                        ),
                      ),
                    _ConnectionTile(
                      connection: connections[i],
                      isBusy:
                          controller.activeProvider == connections[i].provider,
                      onConnect: () => context.go(
                        '/settings/web-view?provider=${connections[i].provider.name}',
                      ),
                    ),
                  ],
                  if (controller.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        controller.errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.connection,
    required this.isBusy,
    required this.onConnect,
  });

  final Connection connection;
  final bool isBusy;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _providerIcon(),
      title: Text(connection.provider.toString()),
      trailing: connection.isAvailable
          ? TextButton(
              onPressed: isBusy
                  ? null
                  : (connection.isConnected ? null : onConnect),
              child: Text(
                connection.isConnected
                    ? 'settings.integrations.actions.disconnect'.tr()
                    : 'settings.integrations.actions.connect'.tr(),
              ),
            )
          : null,
    );
  }

  Widget _providerIcon() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: Colors.white,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Padding(padding: const EdgeInsets.all(6)),
        ),
      ),
    );
  }
}
