import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/user_controller.dart';
import '../../service_locator.dart';

/// Signs in as a guest and opens the dashboard. A failure is shown in a
/// snackbar.
class GuestSignInButton extends StatelessWidget {
  const GuestSignInButton({super.key});

  Future<void> _signIn(BuildContext context, UserController controller) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (await controller.signInAsGuest()) {
      if (context.mounted) context.go('/dashboard');
      return;
    }
    final error = controller.errorMessage;
    if (error != null) {
      messenger?.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = getIt<UserController>();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextButton.icon(
        onPressed: controller.isLoading
            ? null
            : () => _signIn(context, controller),
        icon: const Icon(Icons.person_outline),
        label: Text('auth.social.continue_guest'.tr()),
      ),
    );
  }
}
