import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AuthSubmitButton extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onPressed;

  const AuthSubmitButton({
    super.key,
    required this.isLogin,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(isLogin ? Icons.login : Icons.person_add),
        label: Text(
          isLogin ? 'auth_login'.tr() : 'auth_register'.tr(),
          style: const TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
