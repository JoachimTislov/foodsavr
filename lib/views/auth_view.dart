import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../constants/privacy_notice.dart';
import '../interfaces/auth_service_interface.dart';
import '../service_locator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _logger = getIt<Logger>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final IAuthService _authService;
  bool _isLogin = true;
  String? _errorMessage;
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  bool _agreedToTerms = false; // New state for terms and privacy

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
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        setState(
          () => _errorMessage = 'Email and password cannot be empty.'.tr(),
        );
        return;
      }

      if (!_isLogin && !_agreedToTerms) {
        setState(
          () => _errorMessage =
              'You must agree to the Terms of Service and Privacy Notice.'.tr(),
        );
        return;
      }

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
      setState(() => _errorMessage = e.toString().split(']')[1]);
    }
  }

  void _signInWithGoogle() async {
    setState(() => _errorMessage = null);
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _logger.e('Google Sign-in error: $e');
      setState(() => _errorMessage = e.toString().split(']')[1]);
    }
  }

  void _signInWithFacebook() async {
    setState(() => _errorMessage = null);
    try {
      await _authService.signInWithFacebook();
    } catch (e) {
      _logger.e('Facebook Sign-in error: $e');
      setState(() => _errorMessage = e.toString().split(']')[1]);
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
      setState(() => _errorMessage = e.toString().split(']')[1]);
    }
  }

  void _showPrivacyNotice() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Privacy Notice'.tr()),
          content: SingleChildScrollView(child: Text(PrivacyNotice.content)),
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

  void _showTermsOfService() {
    // TODO: Implement showing terms of service (e.g., in a dialog or new screen)
    _logger.i('Show Terms of Service');
  }

  @override
  Widget build(BuildContext context) {
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
                            ? 'Sign in to manage your kitchen.'
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
                  child: Column(
                    children: [
                      // Email Input
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email Address'.tr(),
                          hintText: 'name@example.com'.tr(),
                          prefixIcon: const Icon(Icons.mail_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2.0,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16.0),

                      // Password Input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password'.tr(),
                          hintText: 'Enter your password'.tr(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2.0,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
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
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24.0),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _authenticate,
                          icon: Icon(_isLogin ? Icons.login : Icons.person_add),
                          label: Text(
                            _isLogin ? 'Login'.tr() : 'Register'.tr(),
                            style: const TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                          ),
                        ),
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
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/2048px-Google_%22G%22_logo.svg.png',
                          height: 24.0,
                          width: 24.0,
                        ),
                        label: Text('Continue with Google'.tr()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Facebook Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _signInWithFacebook,
                        icon: const Icon(Icons.facebook, color: Colors.blue),
                        label: Text('Continue with Facebook'.tr()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),

                // Footer Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin
                          ? 'Don\'t have an account?'.tr()
                          : 'Already have an account?'.tr(),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                          _emailController.clear();
                          _passwordController.clear();
                        });
                      },
                      child: Text(_isLogin ? 'Sign up'.tr() : 'Login'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
