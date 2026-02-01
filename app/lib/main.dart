import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodSavr',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromRGBO(0, 1, 27, .3),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.data == null) {
              return const MyHomePage(title: 'Welcome to FoodSavr');
            } else {
              return const MainAppScreen();
            }
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class MainAppScreen extends StatelessWidget {
  const MainAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => FirebaseAuth.instance.signOut(),
          child: const Text('Sign Out'),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final logger = Logger();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        setState(() => _errorMessage = 'No user found for that email.');
      } else if (e.code == 'wrong-password') {
        setState(() => _errorMessage = 'Wrong password.');
      } else {
        logger.e('Login error: ${e.code} - ${e.message}');
        setState(() => _errorMessage = 'Login failed.');
      }
    }
  }

  void _register(String email, String password) async {
    if (!validateForm(email, password)) return;
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        setState(() => _errorMessage = 'The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        setState(
          () => _errorMessage = 'An account already exists for that email.',
        );
      } else {
        logger.e('Registration error: ${e.code} - ${e.message}');
        setState(() => _errorMessage = 'Registration failed.');
      }
    } catch (e) {
      logger.e('Registration error: $e');
      setState(() => _errorMessage = 'Registration failed.');
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
