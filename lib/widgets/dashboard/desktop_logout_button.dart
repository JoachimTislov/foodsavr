import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../../interfaces/i_auth_service.dart';
import '../../service_locator.dart';

/// Signs out in one click. Signing out deletes a guest account with its data,
/// so a guest confirms first.
class DesktopLogoutButton extends StatefulWidget {
  const DesktopLogoutButton({super.key});

  @override
  State<DesktopLogoutButton> createState() => _DesktopLogoutButtonState();
}

class _DesktopLogoutButtonState extends State<DesktopLogoutButton> {
  bool _signingOut = false;

  Future<bool> _confirmGuestSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.guestLogout.title'.tr()),
        content: Text('settings.guestLogout.message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('settings.logout'.tr()),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _signOut() async {
    final authService = getIt<IAuthService>();
    if (authService.currentUser?.isAnonymous ?? false) {
      if (!await _confirmGuestSignOut() || !mounted) return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failure = 'profile.error_sign_out'.tr();
    setState(() => _signingOut = true);
    try {
      await authService.signOut();
    } catch (e, stack) {
      if (getIt.isRegistered<Logger>()) {
        getIt<Logger>().e('Sign out failed', error: e, stackTrace: stack);
      }
      messenger?.showSnackBar(SnackBar(content: Text(failure)));
    } finally {
      // The router has usually left the shell by now.
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // `tr()` alone does not rebuild the label on a language change.
    EasyLocalization.of(context);
    return OutlinedButton.icon(
      onPressed: _signingOut ? null : _signOut,
      icon: const Icon(Icons.logout),
      label: Text('settings.logout'.tr()),
    );
  }
}
