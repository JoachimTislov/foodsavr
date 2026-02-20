import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:logger/logger.dart';

import '../constants/privacy_notice.dart';
import '../constants/terms_of_service.dart';
import '../interfaces/i_auth_service.dart';
import '../service_locator.dart';
import '../utils/auth_error_handler.dart';
import '../widgets/auth/auth_form_fields.dart';
import '../widgets/auth/auth_submit_button.dart';
import '../widgets/auth/auth_toggle_button.dart';
import '../widgets/auth/social_login_button.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key, required this.title});

  final String title;

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _logger = getIt<Logger>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final IAuthService _authService;
  bool _isLogin = true;
  String? _errorMessage;
  bool _rememberMe = false;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _authService = getIt<IAuthService>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _authenticate() async {
    setState(() => _errorMessage = null);

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    if (!_isLogin && !_agreedToTerms) {
      setState(
        () => _errorMessage =
            'You must agree to the Terms of Service and Privacy Notice.'.tr(),
      );
      return;
    }

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isLogin) {
        await _authService.signIn(
          email: email,
          password: password,
          rememberMe: _rememberMe,
        );
      } else {
        await _authService.signUp(email: email, password: password);
      }
    } catch (e) {
      _logger.e('Auth error: $e');
      setState(() => _errorMessage = AuthErrorHandler.getErrorMessage(e));
    }
  }

  void _signInWithGoogle() async {
    setState(() => _errorMessage = null);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _logger.e('Google Sign-in error: $e');
      setState(() => _errorMessage = AuthErrorHandler.getErrorMessage(e));
    }
  }

  void _signInWithFacebook() async {
    setState(() => _errorMessage = null);
    try {
      await _authService.signInWithFacebook();
    } catch (e) {
      _logger.e('Facebook Sign-in error: $e');
      setState(() => _errorMessage = AuthErrorHandler.getErrorMessage(e));
    }
  }

  void _forgotPassword() async {
    setState(() => _errorMessage = null);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
        () => _errorMessage = 'Please enter your email to reset password.'.tr(),
      );
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email);
      setState(
        () =>
            _errorMessage = 'Password reset email sent. Check your inbox.'.tr(),
      );
    } catch (e) {
      _logger.e('Forgot password error: $e');
      setState(() => _errorMessage = AuthErrorHandler.getErrorMessage(e));
    }
  }

  void _showPrivacyNotice() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('privacy-notice'.tr()),
          content: SingleChildScrollView(child: Text(PrivacyNotice.content)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('close'.tr()),
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
          title: Text('Terms of Service'.tr()),
          content: SingleChildScrollView(child: Text(TermsOfService.content)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                // Header Section
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isLogin ? 'Welcome Back' : 'Create Account',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        _isLogin
                            ? 'Sign in to manage your inventory.'
                            : 'Sign up to start saving time and money.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),

                // Error Message
                if (_errorMessage != null && _errorMessage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Form Section
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AuthFormFields(
                        emailController: _emailController,
                        passwordController: _passwordController,
                      ),
                      const SizedBox(height: 16.0),

                      // Remember Me and Forgot Password (Login only)
                      if (_isLogin)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                ),
                                Text('Remember me'.tr()),
                              ],
                            ),
                            TextButton(
                              onPressed: _forgotPassword,
                              child: Text('Forgot Password?'.tr()),
                            ),
                          ],
                        )
                      else // Terms and Privacy (Register only)
                        Row(
                          children: [
                            Checkbox(
                              value: _agreedToTerms,
                              onChanged: (bool? value) {
                                setState(() {
                                  _agreedToTerms = value ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  text: 'I agree to the '.tr(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                  children: [
                                    TextSpan(
                                      text: 'Privacy Notice'.tr(),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = _showPrivacyNotice,
                                    ),
                                    TextSpan(
                                      text: ' and '.tr(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    TextSpan(
                                      text: 'Terms of Service'.tr(),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = _showTermsOfService,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24.0),

                      // Submit Button
                      AuthSubmitButton(
                        isLogin: _isLogin,
                        onPressed: _authenticate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),

                // Social Login Separator
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'OR'.tr(),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24.0),

                // Social Buttons
                Column(
                  children: [
                    // Google Button
                    SocialLoginButton(
                      text: 'Continue with Google'.tr(),
                      iconPath: 'assets/images/google_logo.svg',
                      color: colorScheme.surface,
                      textColor: colorScheme.onSurface,
                      onPressed: _signInWithGoogle,
                    ),
                    const SizedBox(height: 16.0),

                    // Facebook Button
                    SocialLoginButton(
                      text: 'Continue with Facebook'.tr(),
                      iconPath: 'assets/images/facebook_logo.svg',
                      color: colorScheme.surface,
                      textColor: colorScheme.onSurface,
                      onPressed: _signInWithFacebook,
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),

                // Footer Link
                AuthToggleButton(
                  isLogin: _isLogin,
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = null;
                      _emailController.clear();
                      _passwordController.clear();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
