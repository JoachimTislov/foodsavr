import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../widgets/auth/social_login_button.dart';
import 'auth_view.dart';

class LandingPageView extends StatelessWidget {
  const LandingPageView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      // Background color handled by Theme
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
                    'Inventory Login'.tr(),
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Track, manage, and scale your stock with efficiency.'.tr(),
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Social Login Stack
                  SocialLoginButton(
                    text: 'Continue with Google'.tr(),
                    iconPath: 'assets/images/google_logo.svg',
                    color: colorScheme.surface,
                    textColor: colorScheme.onSurface,
                    onPressed: () {
                      // Ignored as per instructions
                    },
                  ),
                  const SizedBox(height: 16),
                  SocialLoginButton(
                    text: 'Continue with Facebook'.tr(),
                    iconPath: 'assets/images/facebook_logo.svg',
                    color: colorScheme.surface,
                    textColor: colorScheme.onSurface,
                    onPressed: () {
                      // Ignored as per instructions
                    },
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: colorScheme.outlineVariant),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR'.tr(),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: colorScheme.outlineVariant),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Email Button (Primary)
                  // Using standard ElevatedButtonTheme from AppTheme
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AuthView(title: 'Inventory Login'.tr()),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mail_outline),
                        SizedBox(width: 8),
                        Text(
                          'Continue with Email'.tr(),
                          style: TextStyle(
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
                        "Don't have an account?".tr(),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AuthView(title: 'Sign Up'),
                            ),
                          );
                        },
                        child: Text(
                          'Sign up'.tr(),
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
