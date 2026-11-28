import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/adaptive_layout.dart';
import '../constants/material3_config.dart';
import '../widgets/auth/brand_logo.dart';
import '../widgets/auth/public_page_links.dart';
import '../widgets/common/pwa_install_banner.dart';
import '../widgets/landing/landing_feature.dart';

/// The signed-out entry point. "Get started" is where first-run onboarding
/// (#535) begins; it opens sign-up until that flow exists.
class LandingPageView extends StatelessWidget {
  const LandingPageView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final wide = WindowSize.of(context).isExpanded;
    final textAlign = wide ? TextAlign.start : TextAlign.center;

    final hero = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        const BrandLogo(),
        const SizedBox(height: Material3Config.spacing32),
        Semantics(
          header: true,
          child: Text(
            'brand.tagline'.tr(),
            style: (wide ? textTheme.displaySmall : textTheme.headlineLarge)
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: textAlign,
          ),
        ),
        const SizedBox(height: Material3Config.spacing12),
        Text(
          'landing.subtitle'.tr(),
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: textAlign,
        ),
      ],
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LandingFeature(
          icon: Icons.kitchen_outlined,
          title: 'landing.pantry.title'.tr(),
          description: 'landing.pantry.description'.tr(),
        ),
        LandingFeature(
          icon: Icons.schedule,
          title: 'landing.expiry.title'.tr(),
          description: 'landing.expiry.description'.tr(),
        ),
        LandingFeature(
          icon: Icons.checklist,
          title: 'landing.shopping.title'.tr(),
          description: 'landing.shopping.description'.tr(),
        ),
        const SizedBox(height: Material3Config.spacing32),
        FilledButton(
          onPressed: () => context.go('/auth?mode=signup'),
          child: Text('landing.get_started'.tr()),
        ),
        const SizedBox(height: Material3Config.spacing12),
        OutlinedButton(
          onPressed: () => context.go('/auth?mode=login'),
          child: Text('landing.sign_in'.tr()),
        ),
        const SizedBox(height: Material3Config.spacing16),
        const Center(child: PublicPageLinks(showDeleteAccount: false)),
        const PwaInstallBanner(
          margin: EdgeInsets.only(top: Material3Config.spacing16),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Material3Config.spacing24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? 960 : 440),
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: hero),
                        const SizedBox(width: Material3Config.spacing32),
                        Expanded(child: details),
                      ],
                    )
                  : Column(
                      children: [
                        hero,
                        const SizedBox(height: Material3Config.spacing32),
                        details,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
