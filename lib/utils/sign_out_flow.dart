import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../interfaces/i_auth_service.dart';
import '../service_locator.dart';

/// Signs out. Signing out deletes a guest account with its data, so a guest
/// confirms first; a failure is shown in a snackbar.
class SignOutFlow {
  const SignOutFlow._();

  static Future<void> run(BuildContext context) async {
    final authService = getIt<IAuthService>();
    if (authService.currentUser?.isAnonymous ?? false) {
      if (!await _confirmGuestSignOut(context) || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failure = 'profile.error_sign_out'.tr();
    try {
      await authService.signOut();
    } catch (e, stack) {
      if (getIt.isRegistered<Logger>()) {
        getIt<Logger>().e('Sign out failed', error: e, stackTrace: stack);
      }
      messenger?.showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  static Future<bool> _confirmGuestSignOut(BuildContext context) async {
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
}
