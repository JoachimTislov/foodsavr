import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'brand_logo.dart';

class AuthHeader extends StatelessWidget {
  final bool isLogin;

  const AuthHeader({super.key, required this.isLogin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandLogo(),
          const SizedBox(height: 32.0),
          Text(
            isLogin
                ? 'auth.header.welcome_back'.tr()
                : 'auth.header.create_account'.tr(),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            isLogin
                ? 'auth.header.sign_in_subtitle'.tr()
                : 'auth.header.sign_up_subtitle'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
