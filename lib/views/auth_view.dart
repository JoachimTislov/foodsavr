import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../constants/privacy_notice.dart';
import '../constants/terms_of_service.dart';
import '../interfaces/i_auth_service.dart';
import '../service_locator.dart';
import '../services/auth_controller.dart';
import '../widgets/auth/auth_form_fields.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/auth_status_messages.dart';
import '../widgets/auth/auth_submit_button.dart';
import '../widgets/auth/auth_toggle_button.dart';
import '../widgets/auth/social_auth_section.dart';
import '../widgets/auth/terms_and_privacy_checkbox.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key, required this.title});

  final String title;

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _privacyRecognizer = TapGestureRecognizer();
  final _termsRecognizer = TapGestureRecognizer();
  late final AuthController _controller;
  late final StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    _controller = getIt<AuthController>();
    _authSubscription = getIt<IAuthService>().authStateChanges.listen((user) {
      if (user != null && mounted) {
        Navigator.of(context).maybePop();
      }
    });
    _privacyRecognizer.onTap = _showPrivacyNotice;
    _termsRecognizer.onTap = _showTermsOfService;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _privacyRecognizer.dispose();
    _termsRecognizer.dispose();
    _authSubscription.cancel();
    super.dispose();
  }

  void _authenticate() async {
    if (_formKey.currentState?.validate() == true) {
      await _controller.authenticate(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
  }

  void _signInWithGoogle() async {
    await _controller.signInWithGoogle();
  }

  void _signInWithFacebook() async {
    await _controller.signInWithFacebook();
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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthHeader(isLogin: _controller.isLogin),
                    AuthStatusMessages(
                      errorMessage: _controller.errorMessage,
                      successMessage: _controller.successMessage,
                    ),
                    AbsorbPointer(
                      absorbing: _controller.isLoading,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            AuthFormFields(
                              emailController: _emailController,
                              passwordController: _passwordController,
                            ),
                            const SizedBox(height: 16.0),
                            if (_controller.isLogin)
                              _buildLoginOptions()
                            else
                              TermsAndPrivacyCheckbox(
                                value: _controller.agreedToTerms,
                                onChanged: (val) =>
                                    _controller.agreedToTerms = val ?? false,
                                privacyRecognizer: _privacyRecognizer,
                                termsRecognizer: _termsRecognizer,
                              ),
                            const SizedBox(height: 24.0),
                            AuthSubmitButton(
                              isLogin: _controller.isLogin,
                              isLoading: _controller.isLoading,
                              onPressed: _controller.isLoading
                                  ? null
                                  : _authenticate,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24.0),
                    SocialAuthSection(
                      isLoading: _controller.isLoading,
                      onGooglePressed: _signInWithGoogle,
                      onFacebookPressed: _signInWithFacebook,
                    ),
                    const SizedBox(height: 24.0),
                    AuthToggleButton(
                      isLogin: _controller.isLogin,
                      onPressed: _controller.isLoading
                          ? null
                          : () {
                              _controller.isLogin = !_controller.isLogin;
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Checkbox(
              value: _controller.rememberMe,
              onChanged: (val) => _controller.rememberMe = val ?? false,
            ),
            Text('auth.form.remember_me'.tr()),
          ],
        ),
        TextButton(
          onPressed: () => _controller.forgotPassword(_emailController.text),
          child: Text('auth.form.forgot_password'.tr()),
        ),
      ],
    );
  }
}
