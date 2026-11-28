import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../interfaces/i_auth_service.dart';
import '../../service_locator.dart';
import 'add_password_form.dart';
import 'password_reset_form.dart';
import 'settings_action_row.dart';

/// "Add password" for accounts that only sign in through a social provider,
/// and "Forgot password" for accounts that have one. Guests have neither.
class PasswordActionTile extends StatefulWidget {
  final IAuthService? authService;

  /// Called after a password was added to the account.
  final VoidCallback? onChanged;

  const PasswordActionTile({super.key, this.authService, this.onChanged});

  static bool appliesTo(User? user) => user != null && !user.isAnonymous;

  static bool hasPassword(User user) => user.providerData.any(
    (info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
  );

  @override
  State<PasswordActionTile> createState() => _PasswordActionTileState();
}

class _PasswordActionTileState extends State<PasswordActionTile> {
  late final IAuthService _authService =
      widget.authService ?? getIt<IAuthService>();

  Future<void> _addPassword(String? email) async {
    final added = await AddPasswordForm.show(
      context,
      authService: _authService,
      email: email,
    );
    if (!added || !mounted) return;
    setState(() {});
    _notify('settings.password.added'.tr());
    widget.onChanged?.call();
  }

  Future<void> _resetPassword(String? email) async {
    final sent = await PasswordResetForm.show(
      context,
      authService: _authService,
      email: email,
    );
    if (sent && mounted) _notify('auth.reset.email_sent'.tr());
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    // Read on every build: linking replaces the provider list.
    final user = _authService.currentUser;
    if (user == null || !PasswordActionTile.appliesTo(user)) {
      return const SizedBox.shrink();
    }
    return PasswordActionTile.hasPassword(user)
        ? SettingsActionRow(
            icon: Icons.lock_reset,
            title: 'settings.password.title'.tr(),
            subtitle: 'settings.password.resetHint'.tr(),
            action: OutlinedButton(
              onPressed: () => _resetPassword(user.email),
              child: Text('profile.forgot_password'.tr()),
            ),
          )
        : SettingsActionRow(
            icon: Icons.password,
            title: 'settings.password.title'.tr(),
            subtitle: 'settings.password.missingHint'.tr(),
            action: FilledButton(
              onPressed: () => _addPassword(user.email),
              child: Text('settings.password.add'.tr()),
            ),
          );
  }
}
