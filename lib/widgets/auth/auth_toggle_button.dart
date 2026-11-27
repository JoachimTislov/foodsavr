import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AuthToggleButton extends StatelessWidget {
  final bool isLogin;
  final VoidCallback? onPressed;

  const AuthToggleButton({super.key, required this.isLogin, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            isLogin
                ? 'auth.toggle.no_account'.tr()
                : 'auth.toggle.already_have_account'.tr(),
          ),
          TextButton(
            onPressed: onPressed,
            child: Text(
              isLogin ? 'auth.toggle.sign_up'.tr() : 'auth.toggle.login'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}
