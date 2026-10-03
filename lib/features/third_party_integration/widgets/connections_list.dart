import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:foodsavr/injection.dart';
import 'package:go_router/go_router.dart';
import 'package:vector_graphics/vector_graphics.dart';

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
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: Colors.white,
                          child: VectorGraphic(
                            loader: AssetBytesLoader(
                              connections[i].provider.logoPath(),
                            ),
                            height: 40,
                            width: 40,
                            placeholderBuilder: (context) => const SizedBox(
                              height: 40,
                              width: 40,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      title: Text(connections[i].provider.toString()),
                      trailing: connections[i].isAvailable
                          ? TextButton(
                              onPressed:
                                  controller.activeProvider ==
                                      connections[i].provider
                                  ? null
                                  : (connections[i].isConnected
                                        ? null
                                        : () => context.go(
                                            '/settings/web-view?provider=${connections[i].provider.name}',
                                          )),
                              child: Text(
                                connections[i].isConnected
                                    ? 'settings.integrations.actions.disconnect'
                                          .tr()
                                    : 'settings.integrations.actions.connect'
                                          .tr(),
                              ),
                            )
                          : null,
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
