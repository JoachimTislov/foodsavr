import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/privacy_notice.dart';
import '../constants/terms_of_service.dart';
import '../features/auth/auth_providers.dart';
import '../widgets/auth/auth_form_fields.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/auth_status_messages.dart';
import '../widgets/auth/auth_submit_button.dart';
import '../widgets/auth/auth_toggle_button.dart';
import '../widgets/auth/social_auth_section.dart';
import '../widgets/auth/terms_and_privacy_checkbox.dart';

class AuthView extends ConsumerStatefulWidget {
  const AuthView({super.key, required this.title});

  final String title;

  @override
  ConsumerState<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends ConsumerState<AuthView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _privacyRecognizer = TapGestureRecognizer();
  final _termsRecognizer = TapGestureRecognizer();
  @override
  void initState() {
    super.initState();
    _privacyRecognizer.onTap = _showPrivacyNotice;
    _termsRecognizer.onTap = _showTermsOfService;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _privacyRecognizer.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  void _authenticate() async {
    final controller = ref.read(authControllerProvider);
    if (_formKey.currentState?.validate() == true) {
      await controller.authenticate(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
  }

  void _signInWithGoogle() async {
    await ref.read(authControllerProvider).signInWithGoogle();
  }

  void _signInWithFacebook() async {
    await ref.read(authControllerProvider).signInWithFacebook();
  }

  void _showPrivacyNotice() {
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

  void _showTermsOfService() {
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

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(authControllerProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return Column(
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
                        key: _formKey,
                        child: Column(
                          children: [
                            AuthFormFields(
                              emailController: _emailController,
                              passwordController: _passwordController,
                            ),
                            const SizedBox(height: 16.0),
                            if (controller.isLogin)
                              _buildLoginOptions()
                            else
                              TermsAndPrivacyCheckbox(
                                value: controller.agreedToTerms,
                                onChanged: (val) =>
                                    controller.agreedToTerms = val ?? false,
                                privacyRecognizer: _privacyRecognizer,
                                termsRecognizer: _termsRecognizer,
                              ),
                            const SizedBox(height: 24.0),
                            AuthSubmitButton(
                              isLogin: controller.isLogin,
                              isLoading: controller.isLoading,
                              onPressed: controller.isLoading
                                  ? null
                                  : _authenticate,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    SocialAuthSection(
                      isLoading: controller.isLoading,
                      onGooglePressed: _signInWithGoogle,
                      onFacebookPressed: _signInWithFacebook,
                    ),
                    const SizedBox(height: 24.0),
                    AuthToggleButton(
                      isLogin: controller.isLogin,
                      onPressed: controller.isLoading
                          ? null
                          : () {
                              controller.isLogin = !controller.isLogin;
                              _emailController.clear();
                              _passwordController.clear();
                            },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginOptions() {
    final controller = ref.read(authControllerProvider);
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
          onPressed: () => controller.forgotPassword(_emailController.text),
          child: Text('auth.form.forgot_password'.tr()),
        ),
      ],
    );
  }
}
