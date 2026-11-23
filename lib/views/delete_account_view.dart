import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/public_routes.dart';
import '../controllers/user_controller.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text('profile.delete_account'.tr())),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final user = controller.user;
                final verify = controller.deletionRequiresReauthentication;
                final needsPassword =
                    verify && controller.deletionRequiresPassword;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deleted
                          ? 'profile.account_deleted'.tr()
                          : 'profile.delete_account_description'.tr(),
                    ),
                    const SizedBox(height: 16),
                    if (_deleted)
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: Text('profile.back_to_foodsavr'.tr()),
                      )
                    else if (!controller.isInitialized)
                      const CircularProgressIndicator()
                    else if (user == null) ...[
                      Text('profile.sign_in_to_delete'.tr()),
                      FilledButton(
                        onPressed: () =>
                            context.go(PublicRoutes.deleteAccountSignIn),
                        child: Text('profile.sign_in_to_delete_button'.tr()),
                      ),
                    ] else ...[
                      if (verify) Text('auth.error.requires_recent_login'.tr()),
                      if (needsPassword)
                        TextField(
                          controller: _password,
                          onChanged: (_) => setState(() {}),
                          enabled: !controller.isLoading,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'auth.form.password.label'.tr(),
                          ),
                        ),
                      FilledButton(
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
          ),
        ),
      ),
    );
  }
}
