import 'package:app/utils/environment_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';

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

  String validateEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (email.isEmpty) {
      return 'Email cannot be empty.';
    } else if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return '';
  }

  String validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty.';
    } else if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return '';
  }

  bool validateForm(String email, String password) {
    final emailError = validateEmail(email);
    final passwordError = validatePassword(password);
    if (emailError.isNotEmpty || passwordError.isNotEmpty) {
      setState(
        () =>
            _errorMessage = emailError.isNotEmpty ? emailError : passwordError,
      );
    } else {
      setState(() => _errorMessage = null);
    }
    return emailError.isEmpty && passwordError.isEmpty;
  }

  void _login(String email, String password) async {
    if (!validateForm(email, password)) return;
    try {
      await _authService.signInWithEmailAndPassword(email, password);
    } on Exception catch (e) {
      // For a real app, you'd want to handle different exception types
      // from the AuthService.
      setState(() => _errorMessage = 'Login failed.');
      logger.e('Login error: $e');
    }
  }

  void _register(String email, String password) async {
    if (!validateForm(email, password)) return;
    try {
      await _authService.createUserWithEmailAndPassword(email, password);
    } on Exception catch (e) {
      // For a real app, you'd want to handle different exception types
      // from the AuthService.
      setState(() => _errorMessage = 'Registration failed.');
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
            TextField(
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLogin
                      ? 'Don\'t have an account?'
                      : 'Already have an account?',
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _errorMessage = null;
                    });
                  },
                  child: Text(_isLogin ? 'Sign up' : 'Login'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Text(
                _errorMessage ?? '',
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              onPressed: () {
                final email = _emailController.text.trim();
                final password = _passwordController.text.trim();
                if (_isLogin) {
                  _login(email, password);
                } else {
                  _register(email, password);
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isLogin ? 'Login' : 'Register'),
                  Icon(Icons.arrow_right_alt),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
