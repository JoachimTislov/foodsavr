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
  final _privacyRecognizer = TapGestureRecognizer();
  final _termsRecognizer = TapGestureRecognizer();
  late final IAuthService _authService;
  bool _isLogin = true;
  String? _errorMessage;
  String? _successMessage;
  bool _rememberMe = false;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authService = getIt<IAuthService>();
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
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });

    if (_formKey.currentState?.validate() != true) {
      setState(() => _isLoading = false);
      return;
    }

    if (!_isLogin && !_agreedToTerms) {
      setState(() {
        _errorMessage = 'auth_terms_required'.tr();
        _isLoading = false;
      });
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _logger.e('Google Sign-in error: $e');
      setState(() => _errorMessage = AuthErrorHandler.getErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _signInWithFacebook() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });
    try {
      await _authService.signInWithFacebook();
    } catch (e) {
      _logger.e('Facebook Sign-in error: $e');
      setState(() => _errorMessage = AuthErrorHandler.getErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _forgotPassword() async {
    if (_isLoading) return;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isLoading = true;
    });
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'auth_reset_email_prompt'.tr();
        _isLoading = false;
      });
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email);
      setState(() => _successMessage = 'auth_reset_email_sent'.tr());
    } catch (e) {
      _logger.e('Forgot password error: $e');
      setState(() => _errorMessage = AuthErrorHandler.getErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPrivacyNotice() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('common_privacy_notice'.tr()),
          content: SingleChildScrollView(child: Text(PrivacyNotice.content)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('common_close'.tr()),
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
          title: Text('common_terms_of_service'.tr()),
          content: SingleChildScrollView(child: Text(TermsOfService.content)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('common_close'.tr()),
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
                        _isLogin
                            ? 'auth_welcome_back'.tr()
                            : 'auth_create_account'.tr(),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        _isLogin
                            ? 'auth_sign_in_subtitle'.tr()
                            : 'auth_sign_up_subtitle'.tr(),
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
                if (_successMessage != null && _successMessage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _successMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Form Section
                AbsorbPointer(
                  absorbing: _isLoading,
                  child: Form(
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
                                  Text('auth_remember_me'.tr()),
                                ],
                              ),
                              TextButton(
                                onPressed: _forgotPassword,
                                child: Text('auth_forgot_password'.tr()),
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
                                    text: 'auth_agree_prefix'.tr(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                    children: [
                                      TextSpan(
                                        text: 'common_privacy_notice'.tr(),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        recognizer: _privacyRecognizer,
                                      ),
                                      TextSpan(
                                        text: 'common_and'.tr(),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      TextSpan(
                                        text: 'common_terms_of_service'.tr(),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        recognizer: _termsRecognizer,
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
                          isLoading: _isLoading,
                          onPressed: _isLoading ? null : _authenticate,
                        ),
                      ],
                    ),
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
                        'common_or'.tr(),
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
                      text: 'auth_continue_google'.tr(),
                      iconPath: 'assets/images/google_logo.svg',
                      color: colorScheme.surface,
                      textColor: colorScheme.onSurface,
                      onPressed: _isLoading ? null : _signInWithGoogle,
                    ),
                    const SizedBox(height: 16.0),

                    // Facebook Button
                    SocialLoginButton(
                      text: 'auth_continue_facebook'.tr(),
                      iconPath: 'assets/images/facebook_logo.svg',
                      color: colorScheme.surface,
                      textColor: colorScheme.onSurface,
                      onPressed: _isLoading ? null : _signInWithFacebook,
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),

                // Footer Link
                AuthToggleButton(
                  isLogin: _isLogin,
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = null;
                            _successMessage = null;
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
