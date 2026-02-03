import 'package:app/constants/environment_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';
import 'package:app/widgets/auth/auth_form_fields.dart';
import 'package:app/widgets/auth/auth_toggle_button.dart';
import 'package:app/widgets/auth/auth_submit_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final logger = Logger();
  final _emailController = TextEditingController(
    text: EnvironmentConfig.testUserEmail,
  );
  final _passwordController = TextEditingController(
    text: EnvironmentConfig.testUserPassword,
  );
  final AuthService _authService = AuthService(
    AuthRepository(FirebaseAuth.instance),
  );
  bool _isLogin = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login(String email, String password) async {
    setState(() => _errorMessage = null); // Clear previous error messages
    try {
      await _authService.signInWithEmailAndPassword(email, password);
    } on Exception catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
      logger.e('Login error: $e');
    }
  }

  void _register(String email, String password) async {
    setState(() => _errorMessage = null); // Clear previous error messages
    try {
      await _authService.createUserWithEmailAndPassword(email, password);
    } on Exception catch (e) {
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
      logger.e('Registration error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Center(child: Text(widget.title)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLogin ? 'Login' : 'Sign up',
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
              onPressed: () {
                final email = _emailController.text.trim();
                final password = _passwordController.text.trim();
                _isLogin ? _login(email, password) : _register(email, password);
              },
            ),
          ],
        ),
      ),
    );
  }
}
