import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/public_routes.dart';
import '../controllers/user_controller.dart';
import '../widgets/common/url_modal_dialog.dart';

class DeleteAccountView extends StatefulWidget {
  const DeleteAccountView({super.key, required this.controller});

  final UserController controller;

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  final _password = TextEditingController();
  bool _deleted = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete(String userId) async {
    final controller = widget.controller;
    final reauthenticate = controller.deletionRequiresReauthentication;
    if (!reauthenticate) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('profile.delete_account'.tr()),
          content: Text('profile.delete_account_description'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('profile.deleteAccountConfirmation'.tr()),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true || controller.user?.uid != userId) {
        return;
      }
    }

    final password = _password.text;
    _password.clear();
    final deleted = await controller.deleteAccount(
      reauthenticate: reauthenticate,
      password: password.isEmpty ? null : password,
    );
    if (!mounted) return;
    if (deleted) {
      setState(() => _deleted = true);
    } else if (controller.errorMessage case final error?) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return UrlModalDialog(
      title: 'profile.delete_account'.tr(),
      icon: Icons.delete_outline,
      iconColor: colorScheme.error,
      routeBadge: PublicRoutes.deleteAccount,
      primaryCloseButton: false,
      footerLinks: [
        UrlModalLink(
          label: 'common.privacy_notice'.tr(),
          location: PublicRoutes.privacy,
        ),
        UrlModalLink(
          label: 'common.terms_of_service'.tr(),
          location: PublicRoutes.terms,
        ),
      ],
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final user = controller.user;
          final verify = controller.deletionRequiresReauthentication;
          final needsPassword = verify && controller.deletionRequiresPassword;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _deleted
                    ? 'profile.account_deleted'.tr()
                    : 'profile.delete_account_description'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              if (_deleted)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.go('/'),
                    child: Text('profile.back_to_foodsavr'.tr()),
                  ),
                )
              else if (!controller.isInitialized)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (user == null) ...[
                Text(
                  'profile.sign_in_to_delete'.tr(),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go(PublicRoutes.deleteAccountSignIn),
                  child: Text('profile.sign_in_to_delete_button'.tr()),
                ),
              ] else ...[
                if (verify) ...[
                  Text(
                    'auth.error.requires_recent_login'.tr(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (needsPassword) ...[
                  TextField(
                    controller: _password,
                    onChanged: (_) => setState(() {}),
                    enabled: !controller.isLoading,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'auth.form.password.label'.tr(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                  onPressed:
                      controller.isLoading ||
                          (needsPassword && _password.text.isEmpty)
                      ? null
                      : () => _delete(user.uid),
                  child: Text(
                    verify
                        ? 'profile.verify_and_delete'.tr()
                        : 'profile.delete_account'.tr(),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
