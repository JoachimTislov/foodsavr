import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vector_graphics/vector_graphics.dart';

import 'connected_badge.dart';
import 'settings_action_row.dart';

/// One social sign-in provider: connected with its account, or connectable.
class SocialProviderTile extends StatelessWidget {
  static const double _logoSize = 24;

  final String name;
  final String logoPath;

  /// The linked provider account; null when not linked.
  final UserInfo? linked;
  final bool busy;
  final bool canConnect;
  final VoidCallback? onConnect;
  final VoidCallback? onCancel;

  const SocialProviderTile({
    super.key,
    required this.name,
    required this.logoPath,
    required this.linked,
    required this.busy,
    required this.canConnect,
    required this.onConnect,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final email = linked?.email;

    final Widget? action;
    if (linked != null) {
      // Not const, so its label follows a language change.
      action = ConnectedBadge();
    } else if (!canConnect) {
      action = null;
    } else if (busy) {
      action = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: _logoSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: name,
            ),
          ),
          if (onCancel != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'common.cancel'.tr(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      );
    } else {
      action = FilledButton.tonal(
        onPressed: onConnect,
        child: Text(
          'settings.connections.connect'.tr(),
          semanticsLabel: 'settings.connections.connectProvider'.tr(
            namedArgs: {'provider': name},
          ),
        ),
      );
    }

    return SettingsActionRow(
      stackBelow: 280,
      leading: VectorGraphic(
        loader: AssetBytesLoader(logoPath),
        height: _logoSize,
        width: _logoSize,
        placeholderBuilder: (context) => const SizedBox.square(
          dimension: _logoSize,
          child: Icon(Icons.account_circle_outlined, size: 20),
        ),
      ),
      title: name,
      subtitle: linked == null
          ? 'settings.connections.notLinked'.tr()
          : (email != null && email.isNotEmpty)
          ? email
          : 'settings.connections.signInEnabled'.tr(),
      action: action,
    );
  }
}
