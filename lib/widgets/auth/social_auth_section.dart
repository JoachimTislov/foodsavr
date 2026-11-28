import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'social_login_button.dart';

class SocialAuthSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onGooglePressed;
  final VoidCallback? onFacebookPressed;
  final VoidCallback? onCancel;

  const SocialAuthSection({
    super.key,
    required this.isLoading,
    this.onGooglePressed,
    this.onFacebookPressed,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SocialLoginButton(
          text: 'auth.social.continue_google'.tr(),
          iconPath: 'assets/logos/google.svg',
          color: colorScheme.surface,
          textColor: colorScheme.onSurface,
          onPressed: isLoading ? null : onGooglePressed,
        ),
        const SizedBox(height: 12.0),
        SocialLoginButton(
          text: 'auth.social.continue_facebook'.tr(),
          iconPath: 'assets/logos/facebook.svg',
          color: colorScheme.surface,
          textColor: colorScheme.onSurface,
          onPressed: isLoading ? null : onFacebookPressed,
        ),
        if (isLoading && onCancel != null) ...[
          const SizedBox(height: 8.0),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18),
            label: Text('common.cancel'.tr()),
          ),
        ],
      ],
    );
  }
}
