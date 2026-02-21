import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'social_login_button.dart';

class SocialAuthSection extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onGooglePressed;
  final VoidCallback? onFacebookPressed;
  final bool showTopDivider;

  const SocialAuthSection({
    super.key,
    required this.isLoading,
    this.onGooglePressed,
    this.onFacebookPressed,
    this.showTopDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (showTopDivider) ...[
          _buildDivider(context),
          const SizedBox(height: 24.0),
        ],
        SocialLoginButton(
          text: 'auth.social.continue_google'.tr(),
          iconPath: 'assets/images/google_logo.svg',
          color: colorScheme.surface,
          textColor: colorScheme.onSurface,
          onPressed: isLoading ? null : onGooglePressed,
        ),
        const SizedBox(height: 16.0),
        SocialLoginButton(
          text: 'auth.social.continue_facebook'.tr(),
          iconPath: 'assets/images/facebook_logo.svg',
          color: colorScheme.surface,
          textColor: colorScheme.onSurface,
          onPressed: isLoading ? null : onFacebookPressed,
        ),
        if (!showTopDivider) ...[
          const SizedBox(height: 24.0),
          _buildDivider(context),
        ],
      ],
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'common.or'.tr(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
