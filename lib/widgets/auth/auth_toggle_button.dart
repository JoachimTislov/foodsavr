import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AuthToggleButton extends StatelessWidget {
  final bool isLogin;
  final VoidCallback? onPressed;

  const AuthToggleButton({super.key, required this.isLogin, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin ? 'auth_no_account'.tr() : 'auth_already_have_account'.tr(),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(isLogin ? 'auth_sign_up'.tr() : 'auth_login'.tr()),
        ),
      ],
    );
  }
}
