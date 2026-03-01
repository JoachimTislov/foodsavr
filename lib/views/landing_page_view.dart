import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_providers.dart';
import '../widgets/auth/social_auth_section.dart';

class LandingPageView extends ConsumerWidget {
  const LandingPageView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header Section
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: colorScheme.primary,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'auth.landing.title'.tr(),
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'auth.landing.subtitle'.tr(),
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Social Login Stack
                  SocialAuthSection(
                    isLoading: controller.isLoading,
                    onGooglePressed: controller.signInWithGoogle,
                    onFacebookPressed: controller.signInWithFacebook,
                    showTopDivider: false,
                  ),

                  const SizedBox(height: 24),

                  // Divider Section (Manual for Landing Page)
                  // No need to repeat the divider if SocialAuthSection already has one,
                  // but LandingPageView original had its own layout.
                  // Actually SocialAuthSection includes the divider at the TOP.
                  // Let's see how it looks.
                  const SizedBox(height: 24),

                  // Email Button (Primary)
                  ElevatedButton(
                    onPressed: controller.isLoading
                        ? null
                        : () {
                            context.go(
                              Uri(
                                path: '/auth',
                                queryParameters: {
                                  'title': 'auth.landing.title'.tr(),
                                },
                              ).toString(),
                            );
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mail_outline),
                        const SizedBox(width: 8),
                        Text(
                          'auth.social.continue_email'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'auth.toggle.no_account'.tr(),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: controller.isLoading
                            ? null
                            : () {
                                context.go(
                                  Uri(
                                    path: '/auth',
                                    queryParameters: {
                                      'title': 'auth.toggle.sign_up'.tr(),
                                    },
                                  ).toString(),
                                );
                              },
                        child: Text(
                          'auth.toggle.sign_up'.tr(),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
