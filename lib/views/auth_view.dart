import 'package:flutter/material.dart';
import 'package:foodsavr/interfaces/auth_service_interface.dart';
import 'package:logger/logger.dart';
import 'package:easy_localization/easy_localization.dart';

import '../utils/environment_config.dart';
import '../service_locator.dart';
import '../widgets/auth/auth_form_fields.dart';
import '../widgets/auth/auth_toggle_button.dart';
import '../widgets/auth/auth_submit_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _logger = getIt<Logger>();
  final _emailController = TextEditingController(
    text: EnvironmentConfig.testUserEmail,
  );
  final _passwordController = TextEditingController(
    text: EnvironmentConfig.testUserPassword,
  );
  late final IAuthService _authService;
  bool _isLogin = true;
  String? _errorMessage;

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
      _authService.authenticate(
        isLogin: _isLogin,
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // on FirebaseException
    } catch (e) {
      setState(() => _errorMessage = e.toString().split(']')[1]);
      _logger.e('Auth error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Center(child: Text('welcome_message'.tr())),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLogin ? 'login'.tr() : 'signup'.tr(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            AuthFormFields(
              emailController: _emailController,
              passwordController: _passwordController,
            ),
            AuthToggleButton(
              isLogin: _isLogin,
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                  _errorMessage = null;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Text(
                _errorMessage ?? '',
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            AuthSubmitButton(
              isLogin: _isLogin,
              onPressed: () => _authenticate(),
            ),
          ],
        ),
      ),
    );
  }
}
