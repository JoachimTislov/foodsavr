import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../service_locator.dart';
import '../controllers/user_controller.dart';
import '../utils/config.dart';
import '../widgets/auth/auth_form_fields.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/auth_status_messages.dart';
import '../widgets/auth/auth_submit_button.dart';
import '../widgets/auth/auth_toggle_button.dart';
import '../widgets/auth/guest_sign_in_button.dart';
import '../widgets/auth/legal_agreement_notice.dart';
import '../widgets/auth/social_auth_section.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key, this.isLogin = true, this.deletionOnly = false});

  final bool isLogin;
  final bool deletionOnly;

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final UserController _controller;

  @override
  void initState() {
    super.initState();
    _controller = getIt<UserController>();
    _controller.isLogin = widget.isLogin;

    if (Config.isDevelopment) {
      _emailController.text = Config.testUserEmail;
      _passwordController.text = Config.testUserPassword;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  void _signInAsGuest() async {
    // The router keeps guests on /auth so they can upgrade, so leave here.
    if (await _controller.signInAsGuest() && mounted) {
      context.go('/dashboard');
    }
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
                final offersGuest =
                    _controller.isLogin &&
                    !widget.deletionOnly &&
                    !(_controller.user?.isAnonymous ?? false);
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
                            if (_controller.isLogin) _buildLoginOptions(),
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
                      onCancel: _controller.isSocialSignInLoading
                          ? _controller.cancelSocialSignIn
                          : null,
                      // The divider sets guest access apart.
                      showDivider: offersGuest,
                    ),
                    if (offersGuest) ...[
                      const SizedBox(height: 12.0),
                      GuestSignInButton(
                        onPressed: _controller.isLoading
                            ? null
                            : _signInAsGuest,
                      ),
                    ],
                    const SizedBox(height: 24.0),
                    if (!widget.deletionOnly)
                      AuthToggleButton(
                        isLogin: _controller.isLogin,
                        onPressed: _controller.isLoading
                            ? null
                            : () {
                                _controller.isLogin = !_controller.isLogin;
                                _emailController.clear();
                                _passwordController.clear();
                                final mode = _controller.isLogin
                                    ? 'login'
                                    : 'signup';
                                context.go('/auth?mode=$mode');
                              },
                      ),
                    const SizedBox(height: 16.0),
                    LegalAgreementNotice(isLogin: _controller.isLogin),
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
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
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
