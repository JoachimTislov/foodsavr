import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watch_it/watch_it.dart';

import '../constants/privacy_notice.dart';
import '../constants/terms_of_service.dart';
import '../services/auth_controller.dart';
import '../utils/config.dart';
import '../widgets/auth/auth_form_fields.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/auth_status_messages.dart';
import '../widgets/auth/auth_submit_button.dart';
import '../widgets/auth/auth_toggle_button.dart';
import '../widgets/auth/social_auth_section.dart';
import '../widgets/auth/terms_and_privacy_checkbox.dart';

class AuthView extends WatchingWidget {
  const AuthView({super.key, this.isLogin = true});

  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    final emailController = createOnce(() => TextEditingController());
    final passwordController = createOnce(() => TextEditingController());
    final formKey = createOnce(() => GlobalKey<FormState>());
    final privacyRecognizer = createOnce(() => TapGestureRecognizer());
    final termsRecognizer = createOnce(() => TapGestureRecognizer());
    final controller = watchIt<AuthController>();

    // Initial setup (initState equivalent)
    callOnce((context) {
      controller.isLogin = isLogin;
      privacyRecognizer.onTap = () => _showPrivacyNotice(context);
      termsRecognizer.onTap = () => _showTermsOfService(context);

      if (Config.isDevelopment) {
        emailController.text = Config.testUserEmail;
        passwordController.text = Config.testUserPassword;
      }
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthHeader(isLogin: controller.isLogin),
                AuthStatusMessages(
                  errorMessage: controller.errorMessage,
                  successMessage: controller.successMessage,
                ),
                AbsorbPointer(
                  absorbing: controller.isLoading,
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        AuthFormFields(
                          emailController: emailController,
                          passwordController: passwordController,
                        ),
                        const SizedBox(height: 16.0),
                        if (controller.isLogin)
                          _buildLoginOptions(controller, emailController)
                        else
                          TermsAndPrivacyCheckbox(
                            value: controller.agreedToTerms,
                            onChanged: (val) =>
                                controller.agreedToTerms = val ?? false,
                            privacyRecognizer: privacyRecognizer,
                            termsRecognizer: termsRecognizer,
                          ),
                        const SizedBox(height: 24.0),
                        AuthSubmitButton(
                          isLogin: controller.isLogin,
                          isLoading: controller.isLoading,
                          onPressed: controller.isLoading
                              ? null
                              : () => _authenticate(
                                    controller,
                                    formKey,
                                    emailController,
                                    passwordController,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                SocialAuthSection(
                  isLoading: controller.isLoading,
                  onGooglePressed: () => controller.signInWithGoogle(),
                  onFacebookPressed: () => controller.signInWithFacebook(),
                ),
                const SizedBox(height: 24.0),
                AuthToggleButton(
                  isLogin: controller.isLogin,
                  onPressed: controller.isLoading
                      ? null
                      : () {
                          controller.isLogin = !controller.isLogin;
                          emailController.clear();
                          passwordController.clear();
                          final mode = controller.isLogin ? 'login' : 'signup';
                          context.go('/auth?mode=$mode');
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _authenticate(
    AuthController controller,
    GlobalKey<FormState> formKey,
    TextEditingController emailController,
    TextEditingController passwordController,
  ) async {
    if (formKey.currentState?.validate() == true) {
      await controller.authenticate(
        email: emailController.text,
        password: passwordController.text,
      );
    }
  }

  void _showPrivacyNotice(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('common.privacy_notice'.tr()),
          content: SingleChildScrollView(child: Text(PrivacyNotice.content)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.close'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('common.terms_of_service'.tr()),
          content: SingleChildScrollView(child: Text(TermsOfService.content)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('common.close'.tr()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoginOptions(
    AuthController controller,
    TextEditingController emailController,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Checkbox(
              value: controller.rememberMe,
              onChanged: (val) => controller.rememberMe = val ?? false,
            ),
            Text('auth.form.remember_me'.tr()),
          ],
        ),
        TextButton(
          onPressed: () => controller.forgotPassword(emailController.text),
          child: Text('auth.form.forgot_password'.tr()),
        ),
      ],
    );
  }
}
