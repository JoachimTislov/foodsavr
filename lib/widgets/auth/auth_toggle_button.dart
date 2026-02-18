import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AuthToggleButton extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onPressed;

  const AuthToggleButton({
    super.key,
    required this.isLogin,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isLogin
              ? 'Don\'t have an account?'.tr()
              : 'Already have an account?'.tr(),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(isLogin ? 'Sign up'.tr() : 'Login'.tr()),
        ),
      ],
    );
  }
}
